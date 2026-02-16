# Plan Complex Feature Prompt

I want to plan a complex feature before implementing: **[feature description]**

Please help me create a thorough plan:

1. **Understand requirements:**
   - What problem does this solve?
   - Who are the users?
   - What are the success criteria?
   - Any constraints or assumptions?

2. **Break down into sub-features:**
   - Divide into logical, independently testable components
   - Identify dependencies between components
   - Estimate complexity (simple/medium/complex)

3. **Technical design:**
   - What components/modules are needed?
   - How will they interact?
   - Any new dependencies or technologies?
   - Data models, APIs, interfaces?
   - Consider: performance, security, scalability

4. **Create architecture diagram:**
   - Use Mermaid syntax
   - Show components and their relationships
   - Highlight data flow
   - Save to `docs/architecture/[feature].md`

5. **For Formal mode - Create formal specs:**
   - Create spec migration if `spec_migration_mode: enabled`
   - Add features to `spec/FEATURES.md` with:
     - Feature IDs (F-####)
     - Dependencies
     - Acceptance criteria
   - Create acceptance criteria files: `spec/acceptance/F-####.md`
   - Update `spec/PRD.md` or `spec/TECH_SPEC.md` if needed

6. **For Discovery mode - Document in OVERVIEW.md:**
   - Add planned features with acceptance criteria
   - Note technical approach and key decisions
   - List dependencies and risks

7. **Identify risks & unknowns:**
   - What could go wrong?
   - What needs research?
   - What requires human decision?
   - Add to `HUMAN_NEEDED.md` if input needed

8. **Create implementation plan:**
   - Recommended order of work
   - Which tests to write first
   - What can be done in parallel
   - Milestones for validation

9. **Update JOURNAL.md:**
   - Log the planning session
   - Note key decisions and trade-offs

---

**Planning Guidelines:**
- Break complex into simple
- Design for testability
- Consider maintenance burden
- Prefer simple solutions over clever ones
- Think about edge cases early
- Plan for failure modes

**Next steps after planning:**
- Review plan with human if needed
- Create tests (TDD approach)
- Implement incrementally
- Validate each component before moving forward

