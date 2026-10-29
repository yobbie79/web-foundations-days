# TicketHub: Event Ticketing System Design

## 1. Context and Requirements

### 1.1 Context

TicketHub is a website where users can discover concerts and events, view available seats, purchase tickets, and access their bookings. The system must support ordinary daily traffic as well as sudden traffic increases when tickets for a popular concert become available.

The main challenge is ensuring that users can purchase available seats without allowing two people to buy the same seat.

### 1.2 Functional Requirements

The system must allow users to:

1. Register and log in securely.
2. Browse upcoming events and search for specific events.
3. View event details, ticket prices, and available seats.
4. Temporarily hold an available seat while completing checkout.
5. Pay for a ticket using a supported payment provider.
6. Receive confirmation after a successful purchase.
7. View their purchased tickets and order history.
8. Cancel eligible orders according to the event's cancellation policy.
9. Receive clear messages when seats are unavailable or payments fail.

The system must also allow event organisers or authorised administrators to create events, configure seat availability, and manage ticket sales.

### 1.3 Non-Functional Requirements

**Performance:** Event listings and seat availability should load quickly under normal conditions. The target is a response time below 200 milliseconds for common read requests under normal load, where practical. Payment processing may take longer because it depends on an external provider.

**Correctness:** A seat must not be sold to more than one customer. Orders, seat reservations, and payment results must be recorded consistently.

**Availability:** The website should remain usable during high-demand ticket releases. Redundant application servers and health checks reduce the impact of individual server failures.

**Fairness:** Users should receive a clear and consistent opportunity to purchase tickets. A virtual waiting room and rate limits can control excessive requests and help manage sudden demand.

**Security:** HTTPS, secure authentication, authorisation, input validation, and protection against automated abuse are required. Payment card details should be handled by a compliant payment provider rather than stored directly by TicketHub.

**Scalability:** The system should be able to handle large traffic spikes without allowing uncontrolled requests to overwhelm the database.

**Reliability:** Failed payments and interrupted requests must not result in duplicate charges or duplicate ticket sales.

## 2. Traffic and Storage Estimates

The following estimates use the assignment's figures. Where the assignment does not specify a value, the assumption is stated explicitly.

### 2.1 Normal Daily Traffic

There are 2 million registered users, and 50,000 people visit TicketHub on a normal day. Each visitor views 10 pages.

Daily page views:

50,000 visitors × 10 pages = 500,000 page views per day.

Average page views per second:

500,000 ÷ 86,400 ≈ 5.8 page views per second.

For planning, assume the busiest periods reach ten times the daily average:

5.8 × 10 ≈ 58 page views per second.

The system also sells approximately 5,000 tickets on a normal day.

Average ticket sales per second:

5,000 ÷ 86,400 ≈ 0.058 tickets per second.

This is approximately one ticket sale every 17 seconds on average.

### 2.2 Popular Concert Sale

When a popular concert goes on sale, 200,000 people attempt to buy tickets within the first 10 minutes. The event has 20,000 available seats.

Purchase attempts per second:

200,000 ÷ 600 ≈ 333 purchase attempts per second.

If all 20,000 seats sell within those 10 minutes, the average successful sales rate during that period is:

20,000 ÷ 600 ≈ 33 successful sales per second.

The remaining attempts cannot all succeed because demand is ten times greater than the available seat count.

### 2.3 Comparison

| Metric                        |                              Normal day |                          Popular concert sale |
| ----------------------------- | --------------------------------------: | --------------------------------------------: |
| Visitors or purchase attempts |                 50,000 visitors per day |       200,000 purchase attempts in 10 minutes |
| Page views                    |                         500,000 per day |      Additional browsing and checkout traffic |
| Average page views per second |                       Approximately 5.8 |              Can rise sharply during the sale |
| Purchase attempts per second  | Not specified; 5,000 tickets sold daily |                             Approximately 333 |
| Available seats               |                       Depends on events |                                        20,000 |
| Main concern                  | Ordinary response times and reliability | Traffic spikes, seat contention, and fairness |

The big sale produces approximately 333 purchase attempts per second, compared with the normal daily average of about 0.058 completed ticket sales per second. These numbers describe different activities, so they should not be treated as a direct comparison of identical request types.

The important point is that ticketing traffic is uneven. A large number of users can arrive simultaneously, so the system must control access to scarce seats rather than relying only on increasing server capacity.

The estimates exclude additional requests for login, seat maps, availability checks, payment confirmation, and other actions. Actual infrastructure capacity should be determined through load testing.

## 3. API Design

TicketHub exposes a REST API using JSON over HTTPS.

### 3.1 Browse Events

**Method:** `GET`

**Endpoint:** `/api/events`

**Purpose:** Retrieve upcoming events.

**Success response:** `200 OK`

Example response:

```json
{
  "events": [
    {
      "id": 101,
      "name": "Summer Music Festival",
      "venue": "City Arena",
      "date": "2027-06-20",
      "status": "ON_SALE"
    }
  ]
}
```

The endpoint should support pagination and filtering to avoid returning every event in one response.

### 3.2 View Available Seats

**Method:** `GET`

**Endpoint:** `/api/events/{eventId}/seats`

**Purpose:** Retrieve the seats for an event and their current availability.

**Success response:** `200 OK`

Example response:

```json
{
  "eventId": 101,
  "seats": [
    {
      "id": 501,
      "seatNumber": "A1",
      "price": 50.00,
      "status": "AVAILABLE"
    },
    {
      "id": 502,
      "seatNumber": "A2",
      "price": 50.00,
      "status": "SOLD"
    }
  ]
}
```

The displayed availability is informational. The server must check the seat's current state again when a user attempts to hold it.

### 3.3 Hold a Seat

**Method:** `POST`

**Endpoint:** `/api/events/{eventId}/holds`

**Purpose:** Temporarily reserve an available seat for an authenticated user.

**Request body:**

```json
{
  "seatId": 501
}
```

**Success response:** `201 Created`

Example response:

```json
{
  "holdId": 9001,
  "eventId": 101,
  "seatId": 501,
  "status": "HELD",
  "expiresAt": "2027-06-20T12:05:00Z"
}
```

The hold expires after a limited period, for example five minutes. If another user has already held or purchased the seat, the API returns `409 Conflict`.

### 3.4 Pay for an Order

**Method:** `POST`

**Endpoint:** `/api/orders/{orderId}/payment`

**Purpose:** Initiate or confirm payment for an order using a supported payment provider.

**Request body:**

```json
{
  "paymentMethodToken": "provider-generated-token"
}
```

**Success response:** `200 OK` when payment has been confirmed.

Example response:

```json
{
  "orderId": 7001,
  "status": "PAID",
  "message": "Payment confirmed."
}
```

A payment token is a placeholder representing a token supplied by the payment provider. It is not a real payment credential.

If payment fails, the order should remain unpaid and the system should follow its reservation-expiry policy. The backend must verify payment results and use idempotency controls to avoid duplicate charges or duplicate order processing.

### 3.5 View My Tickets

**Method:** `GET`

**Endpoint:** `/api/me/tickets`

**Purpose:** Retrieve tickets belonging to the authenticated user.

**Success response:** `200 OK`

Example response:

```json
{
  "tickets": [
    {
      "ticketId": 8001,
      "eventId": 101,
      "eventName": "Summer Music Festival",
      "seatNumber": "A1",
      "status": "CONFIRMED"
    }
  ]
}
```

The server must derive the user identity from the authenticated session or token, not trust a user ID supplied by the client.

### 3.6 View an Individual Event

**Method:** `GET`

**Endpoint:** `/api/events/{eventId}`

**Purpose:** Retrieve details for one event, including its venue, date, description, and ticket information.

**Success response:** `200 OK`

If the event does not exist, the API returns `404 Not Found`.

### 3.7 Common Error Responses

| Status                      | Meaning                   | Example situation                                |
| --------------------------- | ------------------------- | ------------------------------------------------ |
| `400 Bad Request`           | Invalid input             | A missing or invalid seat ID                     |
| `401 Unauthorized`          | Authentication required   | The user is not logged in                        |
| `403 Forbidden`             | Access denied             | The user attempts to access another user's order |
| `404 Not Found`             | Resource not found        | The event or order does not exist                |
| `409 Conflict`              | Resource state conflict   | Another user already holds the seat              |
| `429 Too Many Requests`     | Rate limit exceeded       | A client sends too many requests                 |
| `500 Internal Server Error` | Unexpected server failure | An unhandled backend error occurs                |

Error responses should contain a consistent JSON structure, for example:

```json
{
  "error": {
    "code": "SEAT_UNAVAILABLE",
    "message": "This seat is no longer available."
  }
}
```

## 4. Data Model

TicketHub uses PostgreSQL because orders, users, events, and seats have structured relationships and require reliable transactions.

The main tables are `users`, `events`, `seats`, `orders`, and `order_items`.

### 4.1 Users

Stores registered customer information.

| Column        | Type         | Constraints      |
| ------------- | ------------ | ---------------- |
| id            | BIGINT       | Primary key      |
| name          | VARCHAR(100) | NOT NULL         |
| email         | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL         |
| created_at    | TIMESTAMP    | NOT NULL         |

Passwords must be securely hashed rather than stored as plain text.

### 4.2 Events

Stores concerts and other events.

| Column     | Type         | Constraints |
| ---------- | ------------ | ----------- |
| id         | BIGINT       | Primary key |
| name       | VARCHAR(200) | NOT NULL    |
| venue      | VARCHAR(200) | NOT NULL    |
| event_date | TIMESTAMP    | NOT NULL    |
| status     | VARCHAR(20)  | NOT NULL    |
| created_at | TIMESTAMP    | NOT NULL    |

The status may indicate whether an event is being prepared, is on sale, or has ended.

### 4.3 Seats

Stores the seats available for each event.

| Column      | Type          | Constraints           |
| ----------- | ------------- | --------------------- |
| id          | BIGINT        | Primary key           |
| event_id    | BIGINT        | Foreign key to events |
| seat_number | VARCHAR(30)   | NOT NULL              |
| price       | NUMERIC(10,2) | NOT NULL              |
| status      | VARCHAR(20)   | NOT NULL              |

A unique constraint on `(event_id, seat_number)` prevents the same seat number from being created twice for one event.

The status can be `AVAILABLE`, `HELD`, or `SOLD`.

### 4.4 Orders

Stores a customer's purchase attempt and its payment state.

| Column       | Type          | Constraints          |
| ------------ | ------------- | -------------------- |
| id           | BIGINT        | Primary key          |
| user_id      | BIGINT        | Foreign key to users |
| status       | VARCHAR(20)   | NOT NULL             |
| total_amount | NUMERIC(10,2) | NOT NULL             |
| created_at   | TIMESTAMP     | NOT NULL             |

Possible statuses include `PENDING`, `PAID`, `FAILED`, and `CANCELLED`.

### 4.5 Order Items

Connects orders to the seats being purchased.

| Column            | Type          | Constraints           |
| ----------------- | ------------- | --------------------- |
| id                | BIGINT        | Primary key           |
| order_id          | BIGINT        | Foreign key to orders |
| seat_id           | BIGINT        | Foreign key to seats  |
| price_at_purchase | NUMERIC(10,2) | NOT NULL              |

A unique constraint on `seat_id` ensures a seat cannot appear in more than one order item. This design assumes the row represents the final allocation of a seat. If the system needs to retain expired reservation attempts, those should be tracked in a separate reservation-history table rather than by creating multiple final allocations.

### 4.6 Relationships

* One user can place many orders.
* One event can have many seats.
* One order can contain multiple order items.
* Each order item refers to one seat.
* Each seat belongs to one event.
* A seat must not be allocated to multiple successful orders.

### 4.7 Preventing Double-Booking

TicketHub must prevent two customers from purchasing the same seat, even if both click the purchase button at nearly the same time.

The system uses database transactions and row-level locking:

1. A user selects an available seat.
2. The backend starts a database transaction.
3. The backend locks the corresponding seat row using `SELECT ... FOR UPDATE`.
4. It checks whether the seat is still available and whether any existing hold is valid.
5. If available, the backend creates a time-limited hold and updates the seat state.
6. The transaction commits, making the hold visible to other requests.
7. Another request for the same seat must wait for the lock and then re-check the seat's state.
8. If the seat is held or sold, the second request receives `409 Conflict` instead of being allowed to reserve the same seat.

The lock must be held within the transaction, and the application must re-check availability after acquiring it.

After successful payment, the system marks the seat as sold and confirms the order using a transaction. If payment fails or a hold expires, the reservation process releases the seat safely.

A database uniqueness constraint provides an additional safeguard against duplicate final seat allocations.

The payment workflow also needs idempotency so that retrying a payment request does not create a second charge or duplicate ticket.

## 5. High-Level Architecture

### 5.1 Architecture Diagram

```text
                          CUSTOMERS
                              |
                              v
                       WEB / MOBILE CLIENT
                              |
                              v
                             DNS
                              |
                              v
                       CDN / STATIC FILES
                              |
                              v
                        LOAD BALANCER
                         /          \
                        v            v
                 APPLICATION A   APPLICATION B
                        \            /
                         \          /
                          v        v
                         SHARED CACHE
                            (Redis)
                              |
                              v
                        PRIMARY DATABASE
                         (PostgreSQL)
                              |
                       Replication to
                              |
                              v
                         READ REPLICA

             APPLICATION SERVERS
                      |
                      v
                 MESSAGE QUEUE
                      |
                      v
              BACKGROUND WORKERS
                      |
                      v
            EMAIL / NOTIFICATIONS

       APPLICATION SERVERS <----> PAYMENT PROVIDER
```

### 5.2 Component Responsibilities

**Web and mobile clients:** Let customers browse events, choose seats, and purchase tickets.

**DNS:** Resolves the TicketHub domain to the appropriate service.

**CDN:** Serves static files such as HTML, CSS, JavaScript, and images from locations closer to users.

**Load balancer:** Distributes incoming requests across healthy application servers.

**Application servers:** Authenticate users, validate requests, enforce business rules, manage seat holds, and coordinate database and payment operations.

**Shared cache:** Stores suitable frequently requested information, such as event details, to reduce repeated database reads. Seat availability must be revalidated against authoritative state before a hold or purchase.

**Primary database:** Stores authoritative seat states, orders, and other transactional data.

**Read replica:** Handles suitable read-only queries to reduce pressure on the primary database. Replication may lag, so seat purchases must not depend on a potentially stale replica.

**Message queue:** Holds background jobs such as sending booking confirmations and notifications.

**Background workers:** Process queued tasks independently of the customer's request.

**Payment provider:** Processes payments and reports their status. TicketHub verifies the result before confirming the purchase.

**Monitoring and alerting:** Track request latency, error rates, queue delays, database health, and seat-sale activity.

### 5.3 GET Request Flow

When a customer browses events:

1. The client sends a `GET /api/events` request over HTTPS.
2. DNS resolves the API domain.
3. The load balancer routes the request to a healthy application server.
4. The server checks whether cached event data can be used.
5. On a cache miss, the server queries the database or an appropriate read replica.
6. The server returns the event data as JSON.
7. The client displays the events.

Frequently accessed event details can be cached. However, information used to confirm a seat purchase must be checked against the authoritative database state.

### 5.4 Purchase Flow

When a customer tries to purchase a seat:

1. The client requests a temporary hold for the selected seat.
2. The load balancer sends the request to an application server.
3. The server authenticates the customer and validates the request.
4. The database transaction locks the seat row and checks its current state.
5. If the seat is available, the server records a temporary hold and commits the transaction.
6. The customer proceeds to payment before the hold expires.
7. The backend confirms the payment with the payment provider.
8. The backend finalises the order and marks the seat as sold.
9. A background job sends the booking confirmation.

If the seat is already held or sold, the request is rejected. If the payment fails, the system follows its hold-expiry and cancellation rules to release the seat safely.

The payment workflow must handle delayed callbacks and retries so that a delayed response cannot accidentally release a seat that has already been paid for.

## 6. Handling the Big Sale

The popular concert sale produces approximately 333 purchase attempts per second during the first 10 minutes. Browsing, authentication, seat selection, and payment create additional requests.

TicketHub handles the spike through the following measures.

### Virtual Waiting Room

A waiting room controls how many customers enter the purchase flow at once. It reduces sudden pressure on the application and database and can provide a more orderly experience.

### Rate Limiting

Rate limits restrict excessive requests from individual clients or accounts. The system should avoid unfairly blocking legitimate users simply because many people share a network.

### Multiple Application Servers

The load balancer distributes requests across multiple stateless application servers. Additional servers can be added as demand increases.

### Caching

Event descriptions, venue information, and other relatively stable content can be cached. Frequently requested public data can be served without querying the primary database every time.

Seat availability used during a purchase must still be validated against the authoritative seat state.

### Database Transactions and Constraints

Row-level locking prevents concurrent transactions from claiming the same seat. Database constraints provide an additional safeguard against duplicate allocations.

### Connection Pooling

Connection pooling limits the number of simultaneous database connections and reuses established connections.

### Background Processing

Booking emails and other non-critical tasks are placed on a queue so they do not slow down the checkout response.

### Monitoring

Monitoring tracks waiting-room size, request latency, failed purchases, database locks, payment errors, and available seat counts. Capacity can then be adjusted based on measured demand.

### Failure Recovery

Multiple application servers, health checks, database backups, replication, and tested failover procedures reduce the impact of component failures.

A read replica does not automatically guarantee database failover; the failover mechanism must be configured and tested.

## 7. Trade-Offs

### Trade-Off 1: Fairness Versus Immediate Access

A virtual waiting room helps control demand and reduces the chance of overwhelming the backend. However, customers may need to wait before entering the purchase flow.

The waiting room should use a clear allocation policy and communicate the user's position or estimated waiting time where possible.

### Trade-Off 2: Caching Versus Correctness

Caching event details reduces database load and improves response times. However, cached seat availability may become outdated when another customer reserves a seat.

The system can cache relatively stable event data but must revalidate the selected seat against the primary database during the reservation transaction.

### Trade-Off 3: Row Locking Versus Throughput

Database row locking prevents two transactions from reserving the same seat. However, many customers competing for a small number of seats can cause lock contention and waiting requests.

The system can limit checkout concurrency, use a waiting room, keep transactions short, and avoid locking unrelated seat rows.

### Trade-Off 4: Strong Consistency Versus Read Scaling

The primary database provides authoritative seat and order state, while read replicas help distribute browsing traffic. Replicas may lag behind the primary database.

This design prioritises correctness for seat allocation and payment confirmation over using replicas for every read.

## 8. Risks and Open Questions

Several decisions require further investigation before production deployment:

* Which payment provider will be used, and how will payment callbacks be verified?
* What is the exact seat-hold duration, and how will expired holds be released?
* Should waiting-room positions be random, first-come-first-served, or based on another published policy?
* What is the required availability target and recovery time after a major failure?
* How long should orders, ticket records, and payment audit information be retained?
* What load-testing results will demonstrate that the system can handle the expected peak?
* How should the system handle a payment that succeeds externally while the application temporarily loses connectivity?

These questions should be resolved through testing, business requirements, and operational planning.

## 9. Conclusion

TicketHub must handle both normal browsing and sudden demand for limited seats. The proposed architecture uses a load balancer, multiple application servers, caching, a relational database, and background workers to support performance and availability.

The most important correctness measure is transactional seat allocation. Row-level locking, availability checks, uniqueness constraints, temporary holds, and idempotent payment processing work together to prevent double-booking.

The design deliberately gives priority to correct seat allocation and payment handling, even when that means some users must wait during a popular sale.
