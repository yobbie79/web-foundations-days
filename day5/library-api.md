# Library Books API

## Overview

The Library Books API provides endpoints for managing a library's book collection. It supports retrieving books, finding individual books, adding new books, updating existing records, deleting books, and searching by author.

**Base URL:** `/api/books`

**Data format:** JSON

## Endpoints

### 1. List All Books

- **Method:** GET
- **Path:** `/api/books`
- **Description:** Retrieves the collection of books.
- **Success status:** `200 OK`

Example response:

```json
[
  {
    "id": 1,
    "title": "Things Fall Apart",
    "author": "Chinua Achebe",
    "publishedYear": 1958
  }
]