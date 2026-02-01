# GLOBAL DEVELOPMENT STANDARDS

## 1. Planning & Process
- **Artifact Generation:** Before implementing any feature, generate a `PLAN.md` covering:
  - User Story & Acceptance Criteria.
  - Technical Approach (Classes/Methods to modify).
  - Potential Risks.
- **Review Protocol:** Do not implement the plan until explicitly approved by the User.

## 2. Code Quality & Structure
- **Access Modifiers:**
  - `public`: Only for external consumers.
  - `protected`: For inheritance chains.
  - `private`: For all internal logic.
- **The "Public-Private" Barrier:** A public method acts as a gateway. It should validate inputs and delegate work to private methods. It must NOT call other public methods within the same instance.
- **Method Size:** Optimize for readability. A method should fit on a standard screen (approx. 20-30 lines).

## 3. Reliability & Security
- **Exception Safety:** All external calls (DB, API, File) must be wrapped in error handling blocks that fail gracefully.
- **Config Separation:** Never hardcode secrets or magic numbers. Use Constants classes or Environment Variables.
- **Testing:** Unit tests are mandatory for all business logic, covering Happy Path, Edge Cases, and Null Inputs.