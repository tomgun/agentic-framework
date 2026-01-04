# Update PRODUCT.md Prompt (Core Mode)

I've made changes to the project and need to update `PRODUCT.md`.

Please help me update:

1. **Features Section:**
   - Add new features implemented
   - Update status of existing features (planned → in progress → done)
   - Note any features that were modified or removed

2. **Technical Details:**
   - Update architecture notes if structure changed
   - Add new dependencies or integrations
   - Note any significant technical decisions

3. **Current Focus:**
   - What's the current state of development?
   - What are the next planned steps?
   - Any open questions or blockers?

4. **Quality Status:**
   - Note test coverage improvements
   - Mention quality checks or standards added
   - Any known issues or technical debt

5. **Update JOURNAL.md:**
   - Log what was changed in this session
   - Note any important decisions or insights

6. **Commit together:**
   - Commit code changes + `PRODUCT.md` + `JOURNAL.md` together
   - Use descriptive commit message

---

**PRODUCT.md is your lightweight spec:**
- In Core mode, it replaces the formal `spec/FEATURES.md`
- Keep it up-to-date with every significant change
- It's the first place anyone (human or AI) should look to understand the project
- Think of it as "living documentation" that evolves with the code

---

**Tip:** If the project is growing complex and you find yourself wishing for more structure, consider upgrading to Core+PM mode:
```bash
bash .agentic/tools/upgrade_profile.sh
```

