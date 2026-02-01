# Research Mode Prompt

I need to research: **[topic, technology, approach, or problem]**

Please conduct a deep research session:

1. **Define scope:**
   - What specifically needs to be researched?
   - What questions need answers?
   - What's the goal (evaluate options, solve problem, learn technology)?

2. **Research strategy:**
   - Check local documentation first (project docs, framework guides)
   - Use Context7 for version-specific library/framework docs
   - Search official documentation, RFCs, authoritative sources
   - Review examples, tutorials, best practices
   - **NEVER hallucinate** - only report verified information

3. **Document findings:**
   - Create research document: `docs/research/[topic].md`
   - Use template from `.agentic/support/docs_templates/research_RESEARCH_TOPIC.md`
   - Include:
     - Research questions
     - Findings with sources/links
     - Evaluation of options (pros/cons)
     - Recommendations
     - Open questions

4. **Practical validation:**
   - If relevant, create small proof-of-concept
   - Test assumptions with code examples
   - Verify claimed performance/behavior

5. **Share insights:**
   - Update `JOURNAL.md` with key findings
   - If research impacts architecture, update `spec/ADR.md` (or create new ADR)
   - If research changes tech direction, update `STACK.md` or `OVERVIEW.md`

6. **Next steps:**
   - Recommend action based on findings
   - Identify any remaining unknowns
   - Suggest experiments or prototypes if needed

---

**Research Guidelines:**
- **Verify everything** - cite sources, check dates, confirm versions
- **Be skeptical** - test claims, look for counterarguments
- **Think critically** - evaluate trade-offs, consider alternatives
- **Document uncertainty** - mark assumptions and gaps in knowledge
- **Focus on actionable insights** - not just information gathering

**Anti-hallucination rules:**
- ✓ Always cite sources for technical claims
- ✓ Use version-specific documentation
- ✓ Test code examples before recommending
- ✓ Say "I don't know" rather than guess
- ✓ Mark speculation as speculation

