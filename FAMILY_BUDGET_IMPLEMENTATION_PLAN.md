# Family Budget Feature - Implementation Plan

## Executive Summary

This document outlines the implementation plan for adding **shared family budget functionality** to the SpendingTracker iOS app. The feature will allow family members to collaboratively manage household finances, track expenses together, and maintain visibility into where money is being spent each month.

---

## Part 1: Research Findings - Indian Family Budget Practices

### 1.1 Budget Categories for Indian Households

Based on research, here are the recommended expense categories tailored for Indian families:

#### **Needs (Essential Expenses) - Target: 50-60%**

| Category | Typical % of Income | Description |
|----------|---------------------|-------------|
| **Housing** | 25-40% | Rent, home loan EMI, property taxes, maintenance |
| **Food & Groceries** | 15-20% | Groceries, cooking essentials, household supplies |
| **Utilities** | 5-8% | Electricity, water, gas, internet, mobile |
| **Healthcare** | 5-7% | Medical expenses, medicines, health insurance premiums |
| **Education** | 10-15% | School/college fees, tuition, books, supplies |
| **Transportation** | 5-10% | Fuel, vehicle EMI, public transport, maintenance |
| **Family Support** | 5-10% | Support for parents/relatives (common in India) |
| **Insurance** | 2-5% | Life insurance, term insurance, vehicle insurance |

#### **Wants (Lifestyle Expenses) - Target: 20-30%**

| Category | Description |
|----------|-------------|
| **Dining Out** | Restaurants, cafes, food delivery |
| **Entertainment** | Movies, OTT subscriptions, events |
| **Shopping** | Clothing, electronics, accessories |
| **Personal Care** | Salon, grooming, cosmetics |
| **Travel & Vacation** | Trips, holidays, weekend getaways |
| **Hobbies** | Sports, fitness, creative activities |
| **Gifts & Donations** | Religious donations, gifts, charity |

#### **Savings & Investments - Target: 20% (Non-negotiable)**

| Category | Description |
|----------|-------------|
| **Emergency Fund** | 3-6 months of expenses |
| **Retirement** | PPF, NPS, EPF contributions |
| **Investments** | Mutual funds, stocks, FDs, gold |
| **Debt Repayment** | Credit card debt, personal loans |
| **Goal-based Savings** | Children's education, wedding, home down payment |

### 1.2 Budget Rules Adapted for India

#### **Standard 50/30/20 Rule**
- 50% → Needs (essentials)
- 30% → Wants (lifestyle)
- 20% → Savings & investments

#### **Indian Adaptation (60/20/20 or 70/10/20)**
Due to higher housing costs in metros and education expenses, many Indian families need:
- 60-70% → Needs
- 10-20% → Wants
- 20% → Savings (keep this constant)

### 1.3 Key Indian Financial Considerations

1. **Joint Family System**: Multiple income sources, shared expenses
2. **Festival Expenses**: Diwali, Holi, Eid, Christmas - seasonal budget spikes
3. **Gold Investments**: Traditional savings method
4. **Education Priority**: Often the largest expense for middle-class families
5. **Healthcare Out-of-Pocket**: 48% of healthcare is self-paid in India
6. **EMI Culture**: Home loans, car loans, personal loans are common
7. **Parent Support**: Financial support for elderly parents is a cultural norm

---

## Part 2: Feature Specification

### 2.1 Core Features

#### **Family/Group Creation**
- Create a "Family Budget" group
- Generate shareable invite codes/links
- Set family budget name and icon
- Define the family's total monthly income (combined)

#### **Member Management**
- Invite family members via email or invite code
- Role-based permissions:
  - **Admin** (Head of family): Full control, can remove members, set budgets
  - **Member**: Can add transactions, view all data
  - **Viewer**: Can only view transactions and budgets (for children/elderly)
- Member profile with display name and avatar

#### **Shared Budget Management**
- Create budgets visible to all family members
- Set budget limits by category
- Option to use 50/30/20 template or custom allocation
- Monthly/weekly/yearly budget periods
- Automatic rollover settings

#### **Transaction Tracking**
- All members can add expenses/income
- Each transaction shows who added it
- Category assignment
- Optional notes and receipt photos
- Real-time sync across all family members' devices

#### **Dashboard & Analytics**
- Family spending overview
- Spending by member breakdown
- Category-wise analysis
- Budget progress indicators
- Month-over-month trends
- Alerts when approaching budget limits

#### **Notifications**
- New transaction added by family member
- Budget limit approaching (80%/100%)
- Weekly/monthly summary
- Member joined/left family

### 2.2 User Stories

| ID | User Story | Priority |
|----|------------|----------|
| US1 | As a family head, I want to create a family budget group so that I can manage our household finances together | High |
| US2 | As a family member, I want to join an existing family budget using an invite code | High |
| US3 | As a family member, I want to add my expenses to the shared budget so others know what was spent | High |
| US4 | As a parent, I want to see what each family member has spent to understand our cash flow | High |
| US5 | As a family head, I want to set monthly budget limits for each category | High |
| US6 | As a family member, I want to receive notifications when a budget is almost exhausted | Medium |
| US7 | As a parent, I want to give my children view-only access to teach them financial awareness | Medium |
| US8 | As a family member, I want to see a dashboard showing our collective spending | High |
| US9 | As a family head, I want to remove a member from the family budget | Medium |
| US10 | As a user, I want to switch between my personal budget and family budget easily | High |

---

## Part 3: Technical Implementation

### 3.1 Data Model Changes

#### **New Models**

```swift
// FamilyBudget.swift
@Model
final class FamilyBudget {
    @Attribute(.unique) var id: String
    var name: String
    var iconName: String
    var monthlyIncome: Decimal
    var createdBy: String // userId
    var inviteCode: String
    var createdAt: Date
    var lastModified: Date
    var isSynced: Bool

    // Relationships
    @Relationship(deleteRule: .cascade) var members: [FamilyMember]
    @Relationship(deleteRule: .cascade) var sharedBudgets: [SharedBudget]
    @Relationship(deleteRule: .cascade) var sharedTransactions: [SharedTransaction]
    @Relationship(deleteRule: .cascade) var sharedCategories: [SharedCategory]
}

// FamilyMember.swift
@Model
final class FamilyMember {
    @Attribute(.unique) var id: String
    var userId: String // Reference to user in Firebase Auth
    var displayName: String
    var email: String
    var role: FamilyRole // admin, member, viewer
    var avatarColorHex: String
    var joinedAt: Date
    var isActive: Bool

    @Relationship var familyBudget: FamilyBudget?
}

enum FamilyRole: String, Codable {
    case admin
    case member
    case viewer
}

// SharedBudget.swift
@Model
final class SharedBudget {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var period: BudgetPeriod
    var startDate: Date
    var alertThreshold: Double
    var isActive: Bool
    var createdBy: String // memberId
    var lastModified: Date
    var isSynced: Bool

    @Relationship var category: SharedCategory?
    @Relationship var familyBudget: FamilyBudget?
}

// SharedTransaction.swift
@Model
final class SharedTransaction {
    @Attribute(.unique) var id: String
    var amount: Decimal
    var note: String
    var date: Date
    var type: TransactionType // expense, income
    var merchantName: String
    var addedBy: String // memberId
    var receiptImageURL: String?
    var lastModified: Date
    var isSynced: Bool

    @Relationship var category: SharedCategory?
    @Relationship var familyBudget: FamilyBudget?
}

// SharedCategory.swift
@Model
final class SharedCategory {
    @Attribute(.unique) var id: String
    var name: String
    var icon: String
    var colorHex: String
    var isExpenseCategory: Bool
    var budgetType: BudgetType // needs, wants, savings
    var sortOrder: Int
    var isSynced: Bool

    @Relationship var familyBudget: FamilyBudget?
}

enum BudgetType: String, Codable {
    case needs
    case wants
    case savings
}
```

### 3.2 Firestore Schema Changes

```
families/{familyId}
  ├── name: string
  ├── iconName: string
  ├── monthlyIncome: number
  ├── createdBy: string (userId)
  ├── inviteCode: string
  ├── createdAt: timestamp
  ├── lastModified: timestamp
  │
  ├── members/{memberId}
  │     ├── userId: string
  │     ├── displayName: string
  │     ├── email: string
  │     ├── role: string (admin/member/viewer)
  │     ├── avatarColorHex: string
  │     ├── joinedAt: timestamp
  │     └── isActive: boolean
  │
  ├── transactions/{transactionId}
  │     ├── amount: number
  │     ├── note: string
  │     ├── date: timestamp
  │     ├── type: string (Expense/Income)
  │     ├── merchantName: string
  │     ├── addedBy: string (memberId)
  │     ├── categoryId: string
  │     ├── receiptImageURL: string?
  │     └── lastModified: timestamp
  │
  ├── budgets/{budgetId}
  │     ├── amount: number
  │     ├── period: string
  │     ├── startDate: timestamp
  │     ├── alertThreshold: number
  │     ├── isActive: boolean
  │     ├── categoryId: string?
  │     ├── createdBy: string (memberId)
  │     └── lastModified: timestamp
  │
  └── categories/{categoryId}
        ├── name: string
        ├── icon: string
        ├── colorHex: string
        ├── isExpenseCategory: boolean
        ├── budgetType: string (needs/wants/savings)
        └── sortOrder: number

// User profile update
users/{userId}
  └── familyIds: [string] // Array of family IDs user belongs to
```

### 3.3 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isFamilyMember(familyId) {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid));
    }

    function isFamilyAdmin(familyId) {
      return isFamilyMember(familyId) &&
        get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)).data.role == 'admin';
    }

    function getMemberRole(familyId) {
      return get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)).data.role;
    }

    // Family collection rules
    match /families/{familyId} {
      // Anyone can read family by invite code (for joining)
      allow read: if isFamilyMember(familyId);
      allow create: if isAuthenticated();
      allow update: if isFamilyAdmin(familyId);
      allow delete: if isFamilyAdmin(familyId);

      // Members subcollection
      match /members/{memberId} {
        allow read: if isFamilyMember(familyId);
        allow create: if isAuthenticated(); // For joining
        allow update: if isFamilyAdmin(familyId) || memberId == request.auth.uid;
        allow delete: if isFamilyAdmin(familyId);
      }

      // Transactions subcollection
      match /transactions/{transactionId} {
        allow read: if isFamilyMember(familyId);
        allow create: if isFamilyMember(familyId) && getMemberRole(familyId) != 'viewer';
        allow update: if isFamilyMember(familyId) && getMemberRole(familyId) != 'viewer';
        allow delete: if isFamilyAdmin(familyId);
      }

      // Budgets subcollection
      match /budgets/{budgetId} {
        allow read: if isFamilyMember(familyId);
        allow write: if isFamilyAdmin(familyId);
      }

      // Categories subcollection
      match /categories/{categoryId} {
        allow read: if isFamilyMember(familyId);
        allow write: if isFamilyAdmin(familyId);
      }
    }
  }
}
```

### 3.4 New Services

#### **FamilyService.swift**
```swift
@Observable
final class FamilyService {
    // Family CRUD
    func createFamily(name: String, monthlyIncome: Decimal) async throws -> FamilyBudget
    func fetchUserFamilies() async throws -> [FamilyBudget]
    func updateFamily(_ family: FamilyBudget) async throws
    func deleteFamily(_ familyId: String) async throws

    // Member Management
    func joinFamily(inviteCode: String) async throws
    func addMember(familyId: String, email: String, role: FamilyRole) async throws
    func updateMemberRole(familyId: String, memberId: String, role: FamilyRole) async throws
    func removeMember(familyId: String, memberId: String) async throws
    func leaveFamily(familyId: String) async throws

    // Generate/Regenerate invite code
    func regenerateInviteCode(familyId: String) async throws -> String

    // Real-time listeners
    func observeFamily(familyId: String) -> AsyncStream<FamilyBudget>
    func observeTransactions(familyId: String) -> AsyncStream<[SharedTransaction]>
}
```

### 3.5 UI/UX Changes

#### **New Screens**

1. **Family Hub Screen** (New tab or section in Settings)
   - List of family budgets user belongs to
   - Create new family button
   - Join family with code

2. **Create Family Screen**
   - Family name input
   - Icon selection
   - Monthly income input
   - Initial budget setup wizard (optional)

3. **Join Family Screen**
   - Enter invite code
   - Show family preview before joining

4. **Family Dashboard Screen**
   - Total spending this month
   - Budget progress rings
   - Spending by member chart
   - Recent transactions (with member avatars)

5. **Family Members Screen**
   - List of members with roles
   - Invite new member
   - Role management (admin only)
   - Remove member option

6. **Shared Transaction Entry Screen**
   - Similar to existing, but with family context
   - Shows "Adding to: [Family Name]"

7. **Family Budget Setup Screen**
   - Category budget allocation
   - 50/30/20 template option
   - Manual budget entry

8. **Family Settings Screen**
   - Edit family name/icon
   - Manage invite code
   - Notification preferences
   - Leave/Delete family

#### **Navigation Changes**

```
MainTabView
├── Dashboard (Personal)
├── Transactions (Personal)
├── Budget (Personal)
├── Family (NEW TAB)
│   ├── Family Hub
│   │   ├── [Family 1] → Family Dashboard
│   │   ├── [Family 2] → Family Dashboard
│   │   ├── Create Family
│   │   └── Join Family
│   └── Family Dashboard
│       ├── Overview
│       ├── Transactions
│       ├── Budgets
│       ├── Members
│       └── Settings
└── Settings (Personal)
```

---

## Part 4: Implementation Phases

### Phase 1: Foundation (2-3 weeks)
**Goal**: Core data models and basic family creation

- [ ] Create new SwiftData models (FamilyBudget, FamilyMember, SharedTransaction, etc.)
- [ ] Set up Firestore collections and security rules
- [ ] Implement FamilyService with basic CRUD operations
- [ ] Create Family Hub screen
- [ ] Implement Create Family flow
- [ ] Add invite code generation

### Phase 2: Member Management (1-2 weeks)
**Goal**: Allow members to join and manage roles

- [ ] Implement Join Family flow with invite codes
- [ ] Build Family Members screen
- [ ] Add role-based permissions
- [ ] Implement member removal/leaving
- [ ] Set up real-time member sync

### Phase 3: Shared Transactions (2 weeks)
**Goal**: Enable collaborative expense tracking

- [ ] Create SharedTransaction entry screen
- [ ] Implement real-time transaction sync
- [ ] Add member attribution to transactions
- [ ] Build transaction list with member avatars
- [ ] Add receipt image upload (optional)

### Phase 4: Family Dashboard & Analytics (2 weeks)
**Goal**: Visualization and insights

- [ ] Build Family Dashboard with spending overview
- [ ] Create spending by member chart
- [ ] Implement category breakdown
- [ ] Add budget progress indicators
- [ ] Build month-over-month trends

### Phase 5: Budget Management (1-2 weeks)
**Goal**: Shared budget creation and tracking

- [ ] Create Family Budget setup screen
- [ ] Implement 50/30/20 template
- [ ] Add custom budget allocation
- [ ] Set up budget alerts
- [ ] Real-time budget progress sync

### Phase 6: Notifications & Polish (1-2 weeks)
**Goal**: Alerts and user experience refinement

- [ ] Implement push notifications for new transactions
- [ ] Add budget alert notifications
- [ ] Create weekly/monthly summary notifications
- [ ] UI polish and animations
- [ ] Testing and bug fixes

### Phase 7: Indian-Specific Features (1 week)
**Goal**: Localization and cultural adaptation

- [ ] Add India-specific default categories
- [ ] Support for festival expense tracking
- [ ] EMI tracking integration
- [ ] Hindi language support (optional)
- [ ] INR formatting throughout

---

## Part 5: Default Categories for Indian Families

### Needs (Essential)
| Category | Icon | Color |
|----------|------|-------|
| Housing/Rent | house.fill | #4A90A4 |
| Groceries | cart.fill | #6B8E23 |
| Utilities | bolt.fill | #FFD700 |
| Education | book.fill | #8B4513 |
| Healthcare | cross.case.fill | #DC143C |
| Transportation | car.fill | #4169E1 |
| Insurance | shield.fill | #2E8B57 |
| Family Support | person.2.fill | #9370DB |
| EMI/Loans | indianrupeesign.circle.fill | #CD853F |

### Wants (Lifestyle)
| Category | Icon | Color |
|----------|------|-------|
| Dining Out | fork.knife | #FF6347 |
| Entertainment | tv.fill | #9932CC |
| Shopping | bag.fill | #FF69B4 |
| Personal Care | sparkles | #FFB6C1 |
| Travel | airplane | #00CED1 |
| Subscriptions | play.rectangle.fill | #FF4500 |
| Gifts & Donations | gift.fill | #DAA520 |
| Festivals | sparkler | #FF8C00 |

### Savings
| Category | Icon | Color |
|----------|------|-------|
| Emergency Fund | banknote.fill | #228B22 |
| Investments | chart.line.uptrend.xyaxis | #008B8B |
| Retirement | clock.fill | #4682B4 |
| Goal Savings | target | #32CD32 |
| Gold/Jewelry | seal.fill | #FFD700 |

---

## Part 6: API Endpoints Summary

### Family Management
| Endpoint | Method | Description |
|----------|--------|-------------|
| `families/` | POST | Create new family |
| `families/{id}` | GET | Get family details |
| `families/{id}` | PUT | Update family |
| `families/{id}` | DELETE | Delete family |
| `families/join/{code}` | POST | Join family via code |

### Member Management
| Endpoint | Method | Description |
|----------|--------|-------------|
| `families/{id}/members` | GET | List all members |
| `families/{id}/members` | POST | Add member |
| `families/{id}/members/{uid}` | PUT | Update member role |
| `families/{id}/members/{uid}` | DELETE | Remove member |

### Transactions
| Endpoint | Method | Description |
|----------|--------|-------------|
| `families/{id}/transactions` | GET | List transactions |
| `families/{id}/transactions` | POST | Add transaction |
| `families/{id}/transactions/{tid}` | PUT | Update transaction |
| `families/{id}/transactions/{tid}` | DELETE | Delete transaction |

### Budgets
| Endpoint | Method | Description |
|----------|--------|-------------|
| `families/{id}/budgets` | GET | List budgets |
| `families/{id}/budgets` | POST | Create budget |
| `families/{id}/budgets/{bid}` | PUT | Update budget |
| `families/{id}/budgets/{bid}` | DELETE | Delete budget |

---

## Part 7: Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Family creation rate | 30% of users | Users who create at least one family |
| Member join rate | 2+ members per family | Average members per family |
| Transaction frequency | 10+ per week per family | Weekly shared transactions |
| Budget compliance | 70% stay within budget | Families not exceeding budgets |
| Retention | 60% monthly active | Family members using app monthly |

---

## Appendix A: Competitive Analysis

| App | Strengths | Weaknesses |
|-----|-----------|------------|
| **Splitwise** | Great for splitting bills, wide adoption | Not a full budget app |
| **Goodbudget** | Envelope system, sync | Dated UI |
| **Monarch** | Beautiful UI, comprehensive | Expensive subscription |
| **Shareroo** | Good for families, receipt scanning | Limited budget features |

**Our Differentiation:**
- India-focused categories and cultural considerations
- 50/30/20 template adapted for Indian families
- Festival and EMI tracking
- Family hierarchy with roles (respecting Indian family structure)
- Offline-first with seamless sync (important for varying network conditions)

---

## Appendix B: Research Sources

- [Data For India - Household Spending](https://www.dataforindia.com/consumption-expenditure/)
- [Remitly - Cost of Living in India 2026](https://www.remitly.com/blog/finance/cost-of-living-in-india/)
- [Feesback - Indian Family Monthly Expenditure](https://www.feesback.org/blog/monthly-expenditure-of-an-indian-family)
- [Motilal Oswal - 50/30/20 Rule India](https://www.motilaloswal.com/learning-centre/2025/5/the-50-30-20-budget-rule-explained-with-examples)
- [HDFC Life - 50/30/20 Rule](https://www.hdfclife.com/savings-plans/50-30-20-rule)
- [Aditya Birla Capital - Monthly Expenses](https://www.adityabirlacapital.com/abc-of-money/monthly-expenses)
- [MoneyCoach - MoneySpaces](https://moneycoach.ai/moneyspaces)
- [Rocket Money - Shared Family Budgeting](https://www.rocketmoney.com/learn/personal-finance/shared-family-budgeting-guide)

---

*Document Created: February 2, 2026*
*Version: 1.0*
*Author: Implementation Team*
