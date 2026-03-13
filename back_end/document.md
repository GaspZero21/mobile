backend/
├── .env.example
├── .gitignore
├── nodemon.json
├── package.json
└── src/
    ├── app.js
    ├── server.js
    ├── config/
    │   ├── database.js
    │   └── jwt.js
    ├── models/
    │   ├── index.js
    │   ├── User.js
    │   ├── Role.js
    │   ├── UserRole.js
    │   ├── UserPreference.js
    │   └── RefreshToken.js
    ├── services/
    │   ├── auth.service.js
    │   ├── token.service.js
    │   ├── user.service.js
    │   └── reputation.service.js
    ├── validators/
    │   ├── auth.validator.js
    │   └── user.validator.js
    ├── middlewares/
    │   ├── auth.middleware.js
    │   ├── rbac.middleware.js
    │   └── error.middleware.js
    ├── controllers/
    │   ├── auth.controller.js
    │   └── user.controller.js
    ├── routes/
    │   ├── auth.routes.js
    │   └── user.routes.js
    └── scripts/
        └── syncDb.js


# 1. Install dependencies
npm install

# 2. Copy and fill in environment variables
cp .env.example .env

# 3. Run the server
npm run dev


---

## API Endpoints

### Auth — /api/v1/auth

Method  Endpoint                    Auth    Description
POST    /api/v1/auth/register       —       Register new user (assigns USER role by default)
POST    /api/v1/auth/login          —       Login and receive access + refresh tokens
POST    /api/v1/auth/refresh        —       Rotate refresh token (revoke old, issue new)
POST    /api/v1/auth/logout         Bearer  Revoke refresh token (body: { refreshToken })
GET     /api/v1/auth/me             Bearer  Get current user from token

Register request body:
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "Password1",
  "phoneNumber": "+33612345678"   // optional
}

Password rules: min 8 chars, at least 1 uppercase letter, at least 1 number.

---

### Users — /api/v1/users

Method  Endpoint                        Auth    Description
GET     /api/v1/users/me                Bearer  Get full profile (roles + preferences + reputation)
PUT     /api/v1/users/profile           Bearer  Update name, avatar, bio
PUT     /api/v1/users/preferences       Bearer  Set notification preferences
GET     /api/v1/users/:id/reputation    —       Get public reputation score and rank

#### PUT /api/v1/users/profile
Updatable fields (all optional):
{
  "name": "Jane Doe",
  "avatar": "https://example.com/avatar.jpg",
  "bio": "I love sharing food!"
}

#### PUT /api/v1/users/preferences
{
  "preferred_categories": ["bread", "vegetables"],
  "notification_radius_km": 5,
  "urgent_only": false
}

Allowed categories: fruits, vegetables, bread, cooked_food, dairy, beverages, other

#### GET /api/v1/users/:id/reputation
Response:
{
  "userId": "57aba69c-...",
  "reputationScore": 84,
  "rank": "Food Saver"
}

Reputation ranks:
  0  – 19  → Newcomer
  20 – 49  → Contributor
  50 – 99  → Food Saver
  100– 199 → Food Champion
  200+     → Food Hero

---

## RBAC Usage

const { authenticateToken } = require('../middlewares/auth.middleware');
const { authorizeRoles } = require('../middlewares/rbac.middleware');

// Single role
router.post('/donations', authenticateToken, authorizeRoles('DONATOR'), handler);

// Multiple roles (user must have at least one)
router.get('/food-dashboard', authenticateToken, authorizeRoles('ADMIN', 'FOOD_SAVER'), handler);

Available roles: USER, DONATOR, BENEFICIARY, FOOD_SAVER, ADMIN, COLLECTIVITE
A user can hold multiple roles simultaneously (e.g. DONATOR + BENEFICIARY).

---

## Reputation Service

Used internally by other modules (donations, reservations, etc.):

const { increaseReputation, decreaseReputation } = require('../services/reputation.service');

await increaseReputation(userId, 5);   // +5 → successful donation
await increaseReputation(userId, 3);   // +3 → successful reservation pickup
await decreaseReputation(userId, 5);   // -5 → cancelled reservation
await increaseReputation(userId, 10);  // +10 → verified by Food Saver

Score never goes below 0.
