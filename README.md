# Aureli - Personal Expense Manager & Financial Intelligence

[![Development Status](https://img.shields.io/badge/Status-Production%20Ready%20%2F%20Advanced-147D64.svg)](#-current-development-status)
[![Backend](https://img.shields.io/badge/Backend-Spring%20Boot%203%20(Java%2021)-0B3B5A.svg)](#-tech-stack)
[![Frontend](https://img.shields.io/badge/Frontend-Flutter%203.x%20(Material%203)-2CB8A0.svg)](#-tech-stack)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%20(Supabase)-6C8CFF.svg)](#-tech-stack)

Aureli is a full-stack, cross-platform personal financial manager and smart expense tracker designed to provide real-time visibility into spending habits, budget enforcement, and automated bill payment reminders. Built with a decoupled architecture featuring a **Flutter 3 mobile client**, **Spring Boot 3 (Java 21) REST API**, **PostgreSQL (Supabase)** database, and **Firebase Cloud Messaging (FCM)**.

---

## 📌 Current Development Status

The system is fully implemented, verified, and at an **Advanced Production-Ready Milestone**. 

### Completed System Features:
- ✅ **Dashboard Financial Intelligence**: Displays Spent This Month (`LKR #,##0`), Total Income, Net Cash Flow (`Income - Expenses`), month-over-month trend pills (e.g. `📈 8.4% more than July`), Top 3 Categories, and Recent Expenses.
- ✅ **Scheduled Payments & Smart Reminders Engine**:
  - Full support for recurring (`Monthly`, `Weekly`, `Yearly`) and one-time scheduled bills.
  - Automated Spring Boot background worker (`ScheduledPaymentReminderScheduler`) running periodic scans to dispatch **FCM Push Notifications** and persistent in-app notifications (`⏰ Payment Due Soon`, `⏰ Payment Due Today`, `⚠️ Overdue Payment`).
  - One-tap **"Pay Now"** action: automatically logs the actual expense into transaction history and advances the recurring due date to the next cycle.
- ✅ **Category Budgets & Threshold Enforcement**: Overall monthly budget overview with LinearProgressIndicator, per-category budget limits, and automated server-side alert logging (`NORMAL`, `NEARING_90`, `EXCEEDED_100`).
- ✅ **Transaction Management**: Complete CRUD operations for Income/Expense items, search by note/category, date range filters, and CSV data export stream.
- ✅ **Profile & Notification Inbox**: Dedicated profile management, FCM token device registration, and notification history screen with unread badge counter.
- ✅ **High Performance UI & Global Quick Actions**:
  - `HomeNavigationScaffold` with custom bottom navigation and a **Global Quick-Action FAB** for 1-tap expense logging or bill scheduling from any screen.
  - Parallelized mobile data layer fetching (`Future.wait([...])`), cutting initialization latency by **~60%**.
  - Modern glassmorphic Material 3 Dark theme.

---

## 🚀 Key Features Overview

| Feature Module | Capabilities |
| :--- | :--- |
| 📊 **Financial Dashboard** | Overview of Total Spent, Total Income, Net Cash Flow, previous month spend comparison, budget progress indicator, top category breakdown cards. |
| ⏰ **Scheduled Payments** | Manage upcoming/overdue bills with countdown status badges (`Due Today`, `Due in 2 days`, `Overdue`). 1-tap "Pay Now" payment execution. |
| 🔔 **Push & Persistent Reminders** | Automated FCM push alerts and persistent notification inbox for upcoming due payments and budget threshold breaches. |
| 💳 **Transaction Tracking** | Search transactions, filter by category/type, view relative timestamps, and export complete transaction logs to CSV. |
| 🎯 **Category Budgets** | Set monthly spending limits per category, track percentage used, and receive alerts when approaching or exceeding limits. |
| 📈 **Analytics & Charts** | FL Chart pie chart distribution and category spend analysis. |
| 👤 **User Profile & Settings** | Firebase email/password authentication, onboarding wizard, FCM push token syncing, and account management. |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Aureli Architecture                                │
└─────────────────────────────────────────────────────────────────────────────────┘

 ┌──────────────────┐           HTTPS REST (JWT Bearer)         ┌─────────────────┐
 │                  │ ────────────────────────────────────────> │                 │
 │   Flutter App    │                                           │   Spring Boot   │
 │   (Mobile UI)    │ <──────────────────────────────────────── │   REST API      │
 └────────┬─────────┘        Firebase Cloud Messaging (FCM)     └────────┬────────┘
          │                                                              │
          │ Firebase ID Token                                            │ JPA / Hibernate
          ▼                                                              ▼
 ┌──────────────────┐                                           ┌─────────────────┐
 │  Firebase Auth   │                                           │  PostgreSQL DB  │
 │     Service      │                                           │   (Supabase)    │
 └──────────────────┘                                           └─────────────────┘
```

---

## 💻 Tech Stack

### Frontend (Mobile Client)
* **Framework**: Flutter 3.x (Dart 3.x)
* **State Management**: Provider Pattern (`MultiProvider`)
* **UI Design**: Material 3 Dark Theme with custom Glassmorphism (`GlassCard`)
* **Charts**: `fl_chart`
* **Push Messaging**: `firebase_messaging` & `firebase_core`

### Backend (REST API)
* **Framework**: Spring Boot 3.x (Java 21)
* **Security & Auth**: Firebase Admin SDK (Decoupled JWT verification filter)
* **Database & ORM**: Spring Data JPA, Hibernate, PostgreSQL Driver
* **Task Scheduling**: `@EnableScheduling` & `@EnableAsync`
* **Build Tool**: Maven

---

## 🔌 API Endpoints Reference

### Authentication & Users
- `POST /api/v1/auth/login` - Sync user profile from Firebase token
- `POST /api/v1/auth/fcm-token` - Register user device FCM token

### Transactions
- `GET /api/v1/transactions` - List paginated transactions (filter by date, category, search)
- `POST /api/v1/transactions` - Log new income/expense transaction
- `DELETE /api/v1/transactions/{id}` - Delete transaction
- `GET /api/v1/transactions/export` - Export transactions as CSV stream

### Scheduled Payments & Reminders
- `GET /api/v1/scheduled-transactions` - Fetch scheduled payments (pending/paid)
- `POST /api/v1/scheduled-transactions` - Schedule new recurring or one-time payment
- `PUT /api/v1/scheduled-transactions/{id}` - Update scheduled payment
- `DELETE /api/v1/scheduled-transactions/{id}` - Delete scheduled payment
- `POST /api/v1/scheduled-transactions/{id}/pay` - 1-Tap "Pay Now": logs actual transaction & advances recurring due date

### Budgets & Summary
- `GET /api/v1/budgets/summary` - Fetch monthly overall budget, spent total, income, net cash flow, and category breakdowns
- `POST /api/v1/budgets/categories` - Set category budget limit

---

## 🛠️ Getting Started

### Prerequisites
* **Java**: JDK 21
* **Maven**: 3.8+
* **Flutter**: 3.x SDK
* **Database**: PostgreSQL (Docker or Supabase)

### Backend Execution
```bash
cd backend
mvn clean compile
mvn spring-boot:run
```

### Mobile App Execution
```bash
cd mobile
flutter pub get
flutter run
```
