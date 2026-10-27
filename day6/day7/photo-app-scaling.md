# Day 7 Assignment: Scaling a Photo-Sharing App

## 1. Assumptions and Load Estimates

SnapShare is a photo-sharing application where users upload photos and view feeds containing photos from people they follow. Before choosing the architecture, I will estimate the amount of traffic and storage the system needs to handle.

I will use the following assumptions:

* The application has 10 million registered users.
* 10% of registered users are active each day.
* Each daily active user uploads one photo per day.
* Each daily active user views 50 feed pages per day.
* Each original photo has an average size of 2 MB.
* Each photo also has a 50 KB thumbnail.
* A day has approximately 86,400 seconds, which I will round to 100,000 seconds for easier calculations.
* Peak traffic is approximately five times the average traffic.
* For storage estimates, I will use decimal units, where 1 GB equals 1,000 MB and 1 TB equals 1,000 GB.

### Daily Active Users

Daily active users are calculated as follows:

10,000,000 registered users × 10%

Daily active users = **1,000,000 users**

### Uploads Per Second

Each active user uploads one photo per day.

1,000,000 users × 1 photo = 1,000,000 uploads per day

Average uploads per second:

1,000,000 ÷ 100,000 ≈ **10 uploads per second**

Peak uploads per second:

10 × 5 = **50 uploads per second**

### Feed Views Per Second

Each active user views 50 feed pages per day.

1,000,000 users × 50 feed views = 50,000,000 feed views per day

Average feed views per second:

50,000,000 ÷ 100,000 ≈ **500 feed views per second**

Peak feed views per second:

500 × 5 = **2,500 feed views per second**

### Photo Storage Per Year

Each active user uploads one 2 MB photo per day.

Daily original photo storage:

1,000,000 photos × 2 MB = 2,000,000 MB

This is approximately 2,000 GB, or 2 TB, per day.

Annual original photo storage:

2 TB × 365 = **730 TB per year**

Each photo also generates a 50 KB thumbnail. Using decimal units, 50 KB equals 0.05 MB.

Daily thumbnail storage:

1,000,000 × 0.05 MB = 50,000 MB = 50 GB

Annual thumbnail storage:

50 GB × 365 = **18.25 TB per year**

Therefore, the total storage for original photos and thumbnails is approximately:

730 TB + 18.25 TB = **748.25 TB per year**

These figures exclude database records, backups, replicas, and other application data. They also assume that all uploaded photos and thumbnails are retained.

### Summary of Estimates

| Measurement              |   Average |      Peak |
| ------------------------ | --------: | --------: |
| Daily active users       | 1,000,000 | 1,000,000 |
| Photo uploads per second |        10 |        50 |
| Feed views per second    |       500 |     2,500 |

The application needs approximately 748.25 TB of additional storage each year for original photos and thumbnails.

## 2. Is SnapShare Read-Heavy or Write-Heavy?

SnapShare is a read-heavy application because users view feed pages much more frequently than they upload photos.

Each day, the system receives approximately 1 million photo uploads and 50 million feed views. This means there are about 50 feed views for every photo upload.

This affects the design because the system must respond quickly to many feed requests without putting too much pressure on the database. I would use caching to store frequently requested feed data and a CDN to deliver photo files and thumbnails close to users. I would also use a load balancer and several application servers to distribute incoming requests.

Photo uploads still need to be handled reliably, but the much higher number of feed views means that improving read performance should be a major priority.

## 3. Where Should Photos Be Stored?

I would store photo files in object storage instead of storing the actual files inside the database.

At approximately 748.25 TB of new photo and thumbnail data each year, keeping all the image files inside the database would make storage management and backups more difficult. It could also increase the work the database must perform when serving photo content.

Object storage is designed to store large numbers of files and can scale to accommodate growing amounts of data. The database would store information about each photo, such as its ID, owner, caption, upload time, and object storage key.

The application could then use that information to retrieve the correct photo from object storage or a CDN. This separates the storage of photo files from the storage of information about those photos.

## 4. Proposed Architecture Diagram

The following diagram shows how I would design SnapShare to support the estimated traffic.

```text
                         USERS
                           |
                           v
                         DNS
                           |
             +-------------+-------------+
             |                           |
             v                           v
       Static files                 API requests
             |                           |
             v                           v
       +-------------+             +-------------+
       |     CDN     |             | Load Balancer|
       | Photos and  |             +------+------+
       | thumbnails  |                    |
       +------+------+             +------+------+
              |                    |             |
              v                    v             v
       +-------------+       +-----------+ +-----------+
       |   Object    |       | App Server| | App Server|
       |   Storage   |       |     1     | |     2     |
       +-------------+       +-----+-----+ +-----+-----+
                                   |             |
                                   +------+------+
                                          |
                        +-----------------+----------------+
                        |                 |                |
                        v                 v                v
                  +-----------+    +-------------+   +-----------+
                  |   Cache   |    |  Primary DB |   |   Queue   |
                  |  (Redis)  |    +------+------+   +-----+-----+
                  +-----------+           |                |
                                          v                v
                                   +-------------+    +-----------+
                                   | Read Replica|    | Thumbnail |
                                   |  Database   |    |  Worker   |
                                   +-------------+    +-----+-----+
                                                            |
                                                            v
                                                     +-------------+
                                                     |   Object    |
                                                     |   Storage   |
                                                     +-------------+
```

The diagram is a simplified view. Both application servers can access the shared cache, database, object storage, and queue. The database read replica receives copies of data from the primary database, while the thumbnail worker reads original photos from object storage and saves the generated thumbnails back to object storage.

## 5. What Each Component Does

* **DNS:** Converts the SnapShare domain name into the address needed to reach the application.
* **CDN:** Delivers photos and thumbnails from nearby servers, reducing loading times and the amount of traffic reaching the origin.
* **Load balancer:** Distributes API requests across healthy application servers so that one server does not handle all the traffic.
* **Application servers:** Handle user requests, check permissions, process uploads, retrieve feed information, and communicate with other components.
* **Cache (Redis):** Stores frequently requested feed data so that the application can respond without querying the database every time.
* **Primary database:** Stores structured information such as users, photo records, captions, and relationships between users.
* **Read replica:** Handles suitable read queries so that feed requests place less pressure on the primary database.
* **Object storage:** Stores original photos and generated thumbnails separately from the database.
* **Message queue:** Holds thumbnail-generation jobs until a worker can process them, preventing image processing from delaying the upload response.
* **Thumbnail worker:** Processes queued jobs by creating smaller versions of uploaded photos and saving them to object storage.

## 6. Step-by-Step Photo Upload Flow

When a user uploads a photo, the following steps take place:

1. The user selects a photo and submits it through the SnapShare application.

2. The request reaches the load balancer, which forwards it to a healthy application server.

3. The application server checks the user's identity, verifies that the user is allowed to upload, and validates the file type and size.

4. The original photo is uploaded to object storage, which returns or confirms the key used to identify the stored file.

5. The application server creates a photo record in the primary database. The record contains information such as the photo ID, owner ID, caption, upload time, and object storage key.

6. The application server adds a thumbnail-generation job to the message queue. The job contains the information needed by the worker to locate and process the original photo.

7. The application responds to the user that the photo has been uploaded successfully. Thumbnail generation can continue in the background instead of making the user wait for the image-processing work to finish.

8. The thumbnail worker retrieves the job from the queue and reads the original photo from object storage.

9. The worker creates a smaller thumbnail, saves it to object storage, and makes its storage key available to the application, for example by updating the photo record in the database.

10. When someone views a feed containing the photo, the application retrieves the necessary feed information from the cache or database. The original photo or thumbnail is then delivered through the CDN, which can retrieve and cache the file from object storage when it does not already have a copy.

This design allows photo uploads to finish without waiting for thumbnail generation. It also separates the work of processing images from the work of handling normal user requests.

## 7. Trade-Offs

### Caching and Data Freshness

Caching makes feed requests faster and reduces database load. However, cached feed information can become outdated when a user uploads a new photo or changes a caption. I would invalidate or update the relevant cached entries when data changes. The trade-off is that cache management adds complexity, and invalidating every affected feed can become difficult as the application grows.

### Database Replication and Consistency

A read replica allows the system to handle more read requests without sending all of them to the primary database. However, changes may take a short time to reach the replica. A user who uploads a photo might therefore not see it immediately in a feed served from a replica. I would allow replicas to serve ordinary feed reads but use the primary database for operations that require the latest data.

### Background Processing and Upload Completion

Using a message queue allows the application to respond before thumbnail generation finishes. This improves the upload experience and prevents image processing from slowing down normal requests. However, thumbnails may not be available immediately, and jobs can fail. The worker should retry suitable failures, while the application should handle photos whose thumbnails are still being processed.

### Multiple Servers and Operational Complexity

Running multiple application servers improves capacity and allows the system to continue operating if one server fails. However, it requires a load balancer, monitoring, health checks, and more deployment work. For this reason, I would begin with a small number of application servers and add more as traffic grows rather than creating an unnecessarily complicated system from the start.

## Conclusion

SnapShare needs an architecture that can handle frequent feed views, reliable photo uploads, and hundreds of terabytes of new image data each year. My design uses a CDN for photo delivery, a load balancer and multiple application servers for API traffic, Redis for caching, a primary database with a read replica for structured data, object storage for images, and a message queue with a thumbnail worker for background processing.

I would start with this architecture at a scale that matches the actual traffic and monitor its performance as the number of users grows. The estimates suggest that feed performance and photo storage are the main areas to plan for, while caching, horizontal scaling, and background processing help keep the application responsive.
