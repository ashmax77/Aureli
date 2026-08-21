# Expense & Budget Tracker

A full-stack, cross-platform Expense and Budget Tracker application built using a modern decoupled architecture. The application consists of a **Flutter mobile client** and a **Spring Boot REST API** backed by **PostgreSQL** (Docker for local development, Supabase for production) and secured with **Firebase Authentication**.

This is a learning project designed to implement clean architecture, secure token-based authentication, and automated background alerts.

---

## 📖 Table of Contents
- [About the Project](#-about-the-project)
- [Key Features](#-key-features)
- [System Architecture](#-system-architecture)
- [Tech Stack](#-tech-stack)
- [Repository Structure](#-repository-structure)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Local Setup](#local-setup)

---

## 🎯 About the Project

Managing personal finances effectively requires clear visibility into spending habits. This application allows users to log expenses, set custom monthly budget limits for different categories, visualize their spending, and receive real-time push notifications when nearing or exceeding budget thresholds.

---

## 🚀 Key Features

* **Secure Authentication**: Firebase Email/Password sign-up and sign-in.
* **Expense Management**: Complete CRUD operations for manual logging and editing.
* **Category Limits**: Define maximum budget limits for individual categories.
* **Progress Tracking**: Real-time spending charts and monthly visual breakdowns.
* **Search & Filters**: Query expenses by date range, category, and amount, with the ability to export data to a CSV sheet.
* **Budget Alerts & Push Notifications**: Automatic server-side checks with push alerts delivered via Firebase Cloud Messaging (FCM) when a category's budget limit is reached or breached.

---

## 🏗️ System Architecture

The application implements a decoupled auth flow to keep user passwords and sensitive credentials outside of our primary application database:

```
┌─────────────────┐           HTTPS (REST)            ┌──────────────────────────┐
│                 │ ────────────────────────────────> │                          │
│   Flutter App   │                                   │   Spring Boot REST API   │
│    (Mobile)     │ <──────────────────────────────── │                          │
└────────┬────────┘      Firebase Cloud Messaging     └────────────┬─────────────┘
         │                       (FCM)                             │
         │                                                         │ JPA/Hibernate
         │ Firebase ID Token                                       │ (JDBC)
         ▼                                                         ▼
┌─────────────────┐                                   ┌──────────────────────────┐
│  Firebase Auth  │                                   │     PostgreSQL DB        │
│    Service      │                                   │  (Docker/Supabase)       │
└─────────────────┘                                   └──────────────────────────┘
```

### Authentication Flow
1. The **Flutter client** authenticates directly with Firebase Auth (email/password).
2. Firebase returns a short-lived cryptographically signed **ID token** to the client.
3. For every API request, the Flutter app includes this token in the `Authorization: Bearer <token>` header.
4. The **Spring Boot Backend** intercepts the request, verifies the token using the Firebase Admin SDK, and automatically creates or references the local `User` record by matching the Firebase UID.

---

## 💻 Tech Stack

### Frontend (Mobile Client)
* **Framework**: Flutter (Dart)
* **Auth SDK**: Firebase Authentication SDK
* **Charts**: `fl_chart` for visual monthly aggregations
* **Push Notifications**: Firebase Cloud Messaging (FCM)

### Backend (REST API)
* **Framework**: Spring Boot 3.x / Java 21
* **Data Access**: Spring Data JPA / Hibernate
* **Database Driver**: PostgreSQL Driver
* **Token Verification**: Firebase Admin SDK
* **Build Tool**: Maven

### Infrastructure & Database
* **Local Development DB**: PostgreSQL running inside Docker Compose
* **Production Database**: Managed PostgreSQL via Supabase
* **Hosting**: Decoupled cloud environment (e.g., Render or Railway)

---

## 🛠️ Getting Started

To run this application locally, you will need to set up the development environment for both the backend and mobile projects.

### Prerequisites
* **Java**: JDK 21
* **Maven**: 3.8+
* **Flutter**: 3.x SDK
* **Docker & Docker Compose**: Installed and running
* **Firebase Project**: An active Firebase project setup with Authentication and Cloud Messaging enabled.

### Local Setup
*(Detailed setup instructions for the database, backend properties, and Flutter environment will be added in subsequent milestones.)*
