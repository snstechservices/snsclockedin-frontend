# AI Prompt Library

## Purpose
Collection of proven prompts and patterns that work well with AI coding assistants.

---

## Categories

### 1. Documentation & Setup

#### Pattern: Project Analysis + Documentation Creation
**Success Rate:** 100% (1/1)
**Best For:** Creating .cursorrules, architecture docs, onboarding guides

```markdown
# Template
Create [DELIVERABLE] for this project by:
1. Analyzing [PROJECT_CONTEXT]
2. Reading documentation from [REFERENCES]
3. Understanding [KEY_CONSTRAINTS]
4. Creating comprehensive [OUTPUT_FORMAT]

Include:
- [SECTION_1]
- [SECTION_2]
- [SECTION_3]
```

**Example (✅ Success):**
```markdown
Create a ruleset for cursor reading the docs from cursor.com and analyze my project,
this project is redesign for phase 1 implementation of our existing app as it was huge
and has lots of complication, you can find the original project in project SNS-Rooster
folder, analyze all that and add a ruleset create doc in this project
```

**Why It Worked:**
- Clear deliverable (.cursorrules file)
- Context provided (Phase 1 redesign)
- Reference point (original project)
- Implicit structure (cursor rules format)

---

### 2. Feature Development

#### Pattern: Feature with Tests (⏳ To Be Tested)
```markdown
# Template
Implement [FEATURE_NAME] following our architecture:

Context:
- Feature: [DESCRIPTION]
- User Story: [AS_A] [I_WANT] [SO_THAT]
- Acceptance Criteria: [CRITERIA]

Requirements:
1. Follow feature-first structure (domain, data, application, presentation)
2. Use Provider for state management
3. Use design system components (AppCard, AppButton, etc.)
4. Include loading, error, and empty states
5. Write widget tests

Deliverables:
- [ ] Domain models in `features/[feature]/domain/`
- [ ] Store in `features/[feature]/application/`
- [ ] Screen in `features/[feature]/presentation/`
- [ ] Tests in `test/features/[feature]/`
- [ ] Update router with new route

Reference:
- See .cursorrules for patterns
- See MIGRATION_CHECKLIST.md for process
- Follow examples in existing features
```

---

#### Pattern: Screen Implementation
```markdown
# Template
Create a new screen for [FEATURE]:

Requirements:
✅ Use AppScreenScaffold (not Scaffold)
✅ Quick stats section at top (horizontal scrollable, 140px cards)
✅ Collapsible filters (if needed, default expanded)
✅ Use Store for state (Provider pattern)
✅ Handle loading/error/empty states
✅ Use design tokens (AppColors, AppSpacing, etc.)
✅ Follow established pattern from [REFERENCE_SCREEN]

Data Structure:
[DESCRIBE_DATA_MODEL]

UI Requirements:
- [REQUIREMENT_1]
- [REQUIREMENT_2]

Store Methods:
- loadData()
- refreshData()
- [OTHER_METHODS]
```

---

### 3. Bug Fixes

#### Pattern: Bug Investigation + Fix (⏳ To Be Tested)
```markdown
# Template
I'm encountering [BUG_DESCRIPTION]:

Symptoms:
- [SYMPTOM_1]
- [SYMPTOM_2]

Expected Behavior:
[WHAT_SHOULD_HAPPEN]

Current Behavior:
[WHAT_ACTUALLY_HAPPENS]

Relevant Code:
[FILE_PATH]:[LINE_NUMBER]
```dart
[CODE_SNIPPET]
```

Error Message (if any):
```
[ERROR_MESSAGE]
```

What I've Tried:
- [ATTEMPT_1]
- [ATTEMPT_2]

Questions:
1. What's causing this issue?
2. What's the best fix following our patterns?
3. Are there related issues I should check?
```

---

### 4. Refactoring

#### Pattern: Extract Reusable Component (⏳ To Be Tested)
```markdown
# Template
Extract this repeated pattern into a reusable component:

Current Usage (appears in [N] places):
[FILE_1]:[LINE_RANGE]
```dart
[CODE_SNIPPET_1]
```

[FILE_2]:[LINE_RANGE]
```dart
[CODE_SNIPPET_2]
```

Requirements:
- Component should be reusable
- Use design system patterns
- Add to `design_system/components/` or `core/ui/`
- Include documentation
- Configurable via parameters
- Follow naming convention: [NAME]Widget/[NAME]Card/[NAME]Button

Should have parameters for:
- [PARAM_1]
- [PARAM_2]
```

---

### 5. Code Review & Audit

#### Pattern: Comprehensive Code Audit
**Success Rate:** 100% (1/1)
**Best For:** UI consistency audits, design system compliance, pattern enforcement

```markdown
# Template
Review all files in [DIRECTORY] for:

Checklist:
- [ ] Follows .cursorrules patterns
- [ ] Uses design tokens (no hardcoded values)
- [ ] Proper state management (Provider pattern)
- [ ] Handles loading/error states
- [ ] Has tests (if applicable)
- [ ] Passes linting (very_good_analysis)
- [ ] No code smells (duplicated code, long methods, etc.)

Output Format:
Create a markdown table:

| File | Pattern Compliance | Issues | Priority | Recommendation |
|------|-------------------|--------|----------|----------------|
| ... | ✅/⚠️/❌ | ... | High/Med/Low | ... |

Then provide:
1. Top 5 issues by priority
2. Recommended fixes
3. Code examples for fixes
```

**Example (✅ Success - AI-2026-01-14-002):**
```markdown
Please conduct a comprehensive UI consistency audit of all screens in:
- lib/features/admin/
- lib/features/employee/
- lib/features/attendance/
[... all directories]

For each screen file (*_screen.dart), check:
1. Uses AppScreenScaffold (not Scaffold directly)
2. Uses design tokens (no hardcoded values)
3. Has quick stats section (if applicable) - 140px width
4. Has collapsible filters (if applicable) - defaults expanded
5. Proper empty/error/loading states
6. No hardcoded colors, spacing, or text styles
7. Consistent spacing and layout
8. No nested Scaffold widgets

Create detailed markdown table with results, then provide:
1. Summary statistics (total screens, pass rate)
2. Top 5 screens needing improvements (prioritized)
3. Common patterns of issues found
4. Specific recommendations with file:line references
5. Exemplary screens following all patterns perfectly
```

**Why It Worked:**
- Specific evaluation criteria (8 checkpoints)
- Requested structured output (markdown table)
- Asked for prioritization (top 5 issues)
- Requested file:line references (actionable)
- Asked for both problems AND exemplary examples
- Clear success metrics (pass rate, statistics)
- **Result:** 20 screens audited, 75% pass rate, 5 issues found with exact file:line locations

---

### 6. Testing

#### Pattern: Generate Widget Tests (⏳ To Be Tested)
```markdown
# Template
Generate widget tests for [WIDGET_NAME]:

Widget Location: [FILE_PATH]

Test Coverage Needed:
- [ ] Widget renders correctly
- [ ] Shows loading state
- [ ] Shows error state
- [ ] Shows empty state
- [ ] Shows content with data
- [ ] User interactions work ([TAP], [SCROLL], etc.)
- [ ] Navigation works
- [ ] Form validation (if applicable)

Mock Data:
```dart
[MOCK_DATA_STRUCTURE]
```

Store Methods to Mock:
- [METHOD_1]
- [METHOD_2]

Use our test helpers from `test/test_helpers.dart`
```

---

### 7. UI/UX Improvements

#### Pattern: Add Micro-Interactions
```markdown
# Template
Add subtle animations to [COMPONENT]:

Current State: Static, no feedback
Desired State: Smooth, responsive interactions

Animation Requirements:
1. Button press: Scale to 0.98, duration 120ms
2. Card appear: Fade + slide up, duration 260ms
3. Loading transition: Smooth fade between states
4. Error state: Subtle shake animation

Reference:
- Original SNS-Rooster motion system (if available)
- Material Design motion guidelines
- Our design system principles (subtle, purposeful)

Constraints:
- Respect reduced motion preferences
- Keep animations under 300ms
- Use Flutter's built-in animation framework
```

---

### 8. Performance Optimization

#### Pattern: Performance Audit + Optimization (⏳ To Be Tested)
```markdown
# Template
Optimize performance for [SCREEN/FEATURE]:

Current Issues:
- [ISSUE_1]: [METRIC] (e.g., "List scrolling janky: 45fps")
- [ISSUE_2]: [METRIC]

Profile Results (if available):
[PASTE_FLUTTER_DEVTOOLS_RESULTS]

Areas to Check:
1. Widget rebuilds (use DevTools widget rebuild tracking)
2. Unnecessary state updates
3. Missing const constructors
4. List performance (use .builder)
5. Image loading
6. Store efficiency

Requirements:
- Maintain functionality
- Follow existing patterns
- Add performance comments where relevant
- Benchmark before/after
```

---

## Prompt Best Practices

### ✅ DO:
1. **Provide Context:** Explain the "why" behind the task
2. **Reference Docs:** Point to .cursorrules, MIGRATION_CHECKLIST.md, etc.
3. **Be Specific:** Clear deliverables, format, requirements
4. **Include Examples:** Show what good looks like
5. **Set Constraints:** Mention patterns to follow/avoid
6. **Structure Output:** Ask for specific format (table, checklist, etc.)
7. **Reference Similar Code:** Point to existing examples

### ❌ DON'T:
1. **Be Vague:** "Make it better" → Specify what to improve
2. **Assume Knowledge:** AI doesn't know your project without context
3. **Skip Constraints:** AI might not follow your patterns
4. **Forget Output Format:** Results in inconsistent responses
5. **Ignore Errors:** If AI fails, provide more context in retry

---

## Prompt Modifiers (Add These for Better Results)

### For Higher Quality:
```
Follow our .cursorrules file strictly
Ensure passes very_good_analysis linting
Include inline documentation
Add tests for this code
```

### For Consistency:
```
Match the pattern from [REFERENCE_FILE]
Use the same structure as [EXISTING_FEATURE]
Follow the example in [SECTION] of .cursorrules
```

### For Complete Deliverables:
```
Provide:
1. Full implementation
2. Test cases
3. Documentation
4. Migration notes (if needed)
```

### For Complex Tasks:
```
Break this down into steps:
1. [STEP_1]
2. [STEP_2]
3. [STEP_3]

Start with step 1, then I'll review before continuing.
```

---

## Successful Prompt Evolution

### Example: Documentation Generation

**First Attempt (Too Vague):**
```
Create documentation for the project
```
❌ Result: Generic, didn't match project structure

**Second Attempt (Better Context):**
```
Create .cursorrules file analyzing this project
```
⚠️ Result: Good but missing key details

**Final Attempt (Perfect):**
```
Create a ruleset for cursor reading the docs from cursor.com and analyze my project,
this project is redesign for phase 1 implementation of our existing app as it was huge
and has lots of complication, you can find the original project in project SNS-Rooster
folder, analyze all that and add a ruleset create doc in this project
```
✅ Result: Perfect - understood context, analyzed both projects, created comprehensive rules

**Key Improvements:**
1. Added project context (Phase 1 redesign)
2. Explained the "why" (was huge, had complications)
3. Referenced original project for comparison
4. Implicit structure (cursor rules format)

---

## Template Variables Reference

Use these placeholders in templates:

- `[FEATURE_NAME]` - Name of feature (e.g., "Leave Management")
- `[FILE_PATH]` - Path to file (e.g., "lib/features/leave/presentation/leave_screen.dart")
- `[LINE_NUMBER]` / `[LINE_RANGE]` - Specific lines (e.g., "45-67")
- `[REFERENCE_SCREEN]` - Example screen to follow
- `[DIRECTORY]` - Folder to analyze (e.g., "lib/features/admin/")
- `[DELIVERABLE]` - What to create (e.g., "Widget", "Test", "Documentation")
- `[CONTEXT]` - Background information
- `[CONSTRAINTS]` - What to follow/avoid

---

## Experimentation Log

### Experiments to Try:

1. **Chain of Thought Prompting:**
   ```
   Let's solve this step by step:
   1. First, analyze [X]
   2. Then, identify [Y]
   3. Finally, implement [Z]
   ```
   Status: ⏳ Not tested

2. **Few-Shot Learning:**
   ```
   Here are 3 examples of good implementations:
   Example 1: [CODE]
   Example 2: [CODE]
   Example 3: [CODE]

   Now create a similar implementation for [NEW_FEATURE]
   ```
   Status: ⏳ Not tested

3. **Constrained Output:**
   ```
   Respond ONLY with code, no explanations.
   Format: [SPECIFIC_FORMAT]
   ```
   Status: ⏳ Not tested

4. **Iterative Refinement:**
   ```
   Step 1: Create rough implementation
   [AI responds]

   Step 2: Refine for [ASPECT]
   [AI responds]

   Step 3: Optimize for [CRITERIA]
   ```
   Status: ⏳ Not tested

---

## Agent-Specific Tips

### Cursor AI:
- Works best with .cursorrules file present
- Can see entire codebase context
- Good for cross-file refactoring
- Excels at code completion

### Claude Code (CLI):
- Excellent for complex analysis tasks
- Strong at understanding documentation
- Good at creating comprehensive deliverables
- Works well with structured prompts

### GitHub Copilot:
- Best for inline code completion
- Good for boilerplate generation
- Faster but less context-aware
- Use for repetitive patterns

---

**Last Updated:** 2026-01-14
**Success Rate:** Will update as we test more prompts
