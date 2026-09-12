# AGENT.md

## Project Development Standards

This document defines the coding standards, architecture, and rules that every developer and AI coding assistant must follow.

---

# Philosophy

* Prioritize readability over cleverness.
* Prefer maintainable code over premature optimization.
* Keep components small and reusable.
* Avoid unnecessary abstractions.
* Follow existing patterns before introducing new ones.
* Consistency is more important than personal preference.

---

# Tech Stack

## Frontend

* Next.js (App Router)
* React
* JavaScript (No TypeScript)
* Tailwind CSS
* Axios
* React Hook Form
* Yup Validation
* TanStack Query
* Zustand
* Lucide React

## Backend

* Node.js
* Express.js
* MongoDB
* Mongoose
* JWT Authentication
* bcrypt

## Deployment

* Docker
* Docker Compose
* Nginx

---

# Language Rules

## Use JavaScript Only

Do not use TypeScript.

Always use:

* const
* let
* async/await
* Optional Chaining

Avoid:

* var
* Promise chains
* Callback hell

### Good

```javascript
const fetchProfile = async () => {};
```

### Bad

```javascript
var fetchProfile = function () {};
```

---

# Next.js Rules

Always use:

* App Router
* Server Components by default
* Client Components only when necessary
* Server Actions when suitable

## Folder Structure

```text
app/
components/
hooks/
services/
store/
utils/
constants/
validators/
contexts/
lib/
public/
```

---

# Styling

Use Tailwind CSS only.

Avoid:

* CSS Modules
* Styled Components
* Inline Styles

### Good

```jsx
<div className="flex items-center gap-4 rounded-xl border p-4">
```

### Bad

```jsx
<div style={{ display: "flex" }}>
```

---

# Icons

Always use:

* lucide-react

Avoid:

* Heroicons
* Font Awesome
* Material Icons

---

# API Calls

Always use Axios.

Never use:

```javascript
fetch();
```

Create:

```text
services/
└── axiosInstance.js
```

Example:

```javascript
const response = await axiosInstance.get("/users");
```

---

# State Management

## Global State

Use:

* Zustand

## Server State

Use:

* TanStack Query

Avoid Redux unless absolutely necessary.

---

# Form Handling

Always use:

* React Hook Form
* Yup Validation

Avoid:

* useState for every input field

---

# Component Rules

Components must have a single responsibility.

Maximum:

* 300 lines per component

Split large components into smaller components.

### Good

```text
UserCard.jsx
UserAvatar.jsx
UserInfo.jsx
```

### Bad

```text
UserEverything.jsx
```

---

# Naming Convention

## Components

```text
LoginForm.jsx
ProfileCard.jsx
UserTable.jsx
```

## Hooks

```text
useAuth.js
useProfile.js
```

## Services

```text
authService.js
courseService.js
```

## Stores

```text
authStore.js
themeStore.js
```

## Constants

```text
roles.constants.js
api.constants.js
```

---

# Import Order

```javascript
// External Libraries
// Components
// Hooks
// Store
// Services
// Utils
// Constants
```

---

# Backend Folder Structure

```text
src/

├── controllers/
├── routes/
├── models/
├── middleware/
├── services/
├── validators/
├── utils/
├── config/
├── constants/
├── db/
```

---

# Database

Use:

* MongoDB
* Mongoose

Model Names:

```text
User.js
Profile.js
Course.js
```

Avoid deeply nested schemas.

---

# Authentication

Use:

* Access Token
* Refresh Token

Passwords must always be hashed using bcrypt.

## Access Token

Purpose:

* Authenticate API requests

Lifetime:

* 15 minutes

Storage:

* Memory
* HTTP-only cookie

## Refresh Token

Purpose:

* Generate new access tokens

Lifetime:

* 7–30 days

Storage:

* HTTP-only cookie

Refresh tokens should be stored in the database.

Example:

```javascript
{
  refreshToken;
}
```

Logout must invalidate refresh tokens.

---

# JWT Environment Variables

```env
ACCESS_TOKEN_SECRET=
REFRESH_TOKEN_SECRET=
ACCESS_TOKEN_EXPIRES=15m
REFRESH_TOKEN_EXPIRES=7d
```

---

# API Response Format

## Success Response

```json
{
  "success": true,
  "message": "Profile fetched successfully",
  "data": {}
}
```

## Error Response

```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

---

# Error Handling

Always use:

```javascript
try {
} catch (error) {
}
```

Return:

```javascript
return res.status(400).json({
  success: false,
  message: error.message,
});
```

---

# Environment Variables

Never hardcode:

* Database URLs
* JWT Secrets
* API Keys

Use:

```text
.env
.env.production
```

---

# Docker Standards

Every project must support Docker.

Required files:

```text
Dockerfile
docker-compose.yml
.dockerignore
```

---

# Docker Compose

Prefer Docker Compose for development.

Services may include:

```yaml
services:
  frontend:
  backend:
  mongodb:
  nginx:
```

---

# Container Naming Convention

Use:

```text
project_frontend
project_backend
project_nginx
project_mongodb
```

Avoid random container names.

---

# Docker Commands

## Build

```bash
docker compose build
```

## Start

```bash
docker compose up -d
```

## Stop

```bash
docker compose down
```

## Logs

```bash
docker compose logs -f
```

## Restart

```bash
docker compose restart
```

---

# Deployment Stack

Production stack:

* Docker
* Docker Compose
* Nginx

Avoid PM2 if Docker is being used.

---

# Git Branches

## Feature

```text
feature/login
feature/dashboard
```

## Bug Fix

```text
bugfix/auth
```

## Hot Fix

```text
hotfix/payment
```

## Refactor

```text
refactor/navbar
```

---

# Commit Messages

Use:

```text
feat:
fix:
refactor:
docs:
style:
chore:
```

Examples:

```text
feat: add login API
fix: resolve refresh token issue
refactor: optimize profile controller
```

---

# Code Quality

Use:

* ESLint
* Prettier

Remove:

* console.log
* unused imports

Avoid:

* nested ternary operators
* duplicated code

---

# Security

Never expose:

* JWT Secrets
* Database URLs
* API Keys

Always:

* Validate request data
* Sanitize inputs
* Hash passwords with bcrypt
* Use HTTP-only cookies
* Configure CORS properly

---

# AI Assistant Instructions

When generating code:

* Follow existing project structure
* Use JavaScript only
* Use Next.js App Router
* Use Tailwind CSS
* Use Axios
* Use Lucide React
* Use React Hook Form with Yup
* Use Zustand
* Use TanStack Query
* Keep components small
* Prefer reusable utilities
* Prefer async/await
* Write production-ready code

Do NOT:

* Use TypeScript
* Use Redux
* Use fetch()
* Use CSS Modules
* Introduce unnecessary dependencies
* Change architecture without reason

---

# Golden Rule

> Write code that another developer can understand six months later.
