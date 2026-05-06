# Student Finance & Co-op Planner

Full-stack cross-platform app to help students manage money during school and co-op terms with a **Plan vs. Reality** workflow.

## Tech Stack

- Mobile: React Native + Expo + TypeScript
- Backend: Node.js + Express + TypeScript
- Database: MongoDB + Mongoose
- Auth: JWT
- Charts: react-native-chart-kit

## Monorepo Structure

- `mobile`: Expo mobile client
- `backend`: Express API

## Features Implemented

- JWT authentication (`/auth/register`, `/auth/login`)
- Profile setup endpoint (`/profile`)
- Planning endpoints for:
  - income sources
  - budget categories
  - tuition payments
  - loans/scholarships/bursaries/gifts/extra income
  - savings goals
- Quick-add transactions (`/transactions`)
- Dashboard snapshot (`/dashboard`) with:
  - monthly balance
  - planned vs actual delta
  - category budget progress
  - savings goal progress
  - awareness messages
- Mobile auth + dashboard + quick-add flow
- Mobile starter plan setup action
- Mobile spending trend chart

## Getting Started

1. Install dependencies:

```bash
npm install
```

2. Configure backend environment:

```bash
cp backend/.env.example backend/.env
```

3. Start backend:

```bash
npm run dev:backend
```

4. Start mobile app:

```bash
npm run start:mobile
```

## Notes

- Mobile API base URL is currently `http://localhost:4000`.
- For physical devices, update `mobile/src/api/client.ts` to your machine LAN IP.
- AI insights (Gemini) are intentionally not included yet, per project scope.
