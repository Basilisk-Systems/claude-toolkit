---
name: writing
description: Human-passing writing that defeats AI detection. Use when writing blog posts, marketing copy, documentation prose, email drafts, or any text meant to read as if a person wrote it. TRIGGER when user asks to write, draft, or edit prose content (blog posts, web copy, articles, emails, bios). Do NOT trigger for code comments, commit messages, or technical docs like READMEs.
allowed-tools: Read, Bash, Edit, Write, WebSearch, WebFetch
---

# Human-Passing Writing Skill

Write prose that a reader (or AI-detection tool) would attribute to a human author. Every rule below exists because AI text has a statistical fingerprint. The goal is to break that fingerprint while keeping the writing clear and good.

---

## The Core Problem

AI detection works by measuring how "expected" each word choice is. LLMs pick high-probability tokens by design, which produces text that is fluent but statistically flat. Human writing is lumpy: uneven sentence lengths, idiosyncratic word choices, structural asymmetry, and occasional rough edges that a language model would smooth away.

Your job is to write like a specific person explaining something they know well, not like a language model completing a prompt.

---

## Banned Patterns (Hard Rules)

These are the highest-signal AI markers. Never use them.

### 1. Em-dashes
- **Never use `—` (em-dash)**. AI overuses them 5-10x compared to human writers.
- Rewrite using periods, commas, parentheses, or "which" clauses instead.
- A single hyphen `-` for compound adjectives is fine ("well-known vendor").

### 2. Groups of Three
- Never list exactly three items in "X, Y, and Z" form. AI defaults to triads constantly.
- Use two items, four items, or break the list across sentences.
- If three items are genuinely the right number, use a different structure (numbered list, separate sentences, "along with" phrasing).

### 3. Parallel Sentence Structures
- Never repeat the same grammatical template across consecutive blurbs, bullet points, or paragraphs.
- If writing multiple cards/sections, vary the sentence opener, length, and structure of each one.
- Bad: "Our X service helps you Y." / "Our A service helps you B." / "Our C service helps you D."
- Good: Mix declarative, question, fragment, or "You'll..." / "This is where..." / "Most companies..." openers.

### 4. "Not Just X, but Y" Antithesis
- Avoid "not just... but also...", "more than just...", "it's not about X, it's about Y".
- This rhetorical pattern is an AI signature. Rephrase directly.

### 5. Corporate Filler Words
Never use these words or phrases in prose:
- comprehensive, streamline, seamless, cutting-edge, state-of-the-art
- leverage (as a verb), utilize (just say "use"), facilitate
- robust, innovative, revolutionary, game-changing, next-generation
- team of experts, deep expertise, unparalleled, best-in-class
- elevate, empower, unlock, transform (as marketing verbs)
- holistic, synergy, ecosystem (outside technical contexts)
- delve, navigate (as metaphors), realm, landscape (as metaphors)
- it's worth noting, it's important to note, interestingly

### 6. Smooth Transition Words
- Avoid: "Moreover", "Furthermore", "In addition", "That said", "Having said that", "With that in mind", "In today's [X]..."
- Humans mostly just start the next thought. Use "And", "But", "So", "The other thing is", "Then there's", or just a new paragraph with no transition.

### 7. Formulaic Conclusions
- Never write "In conclusion", "To sum up", "All in all", "At the end of the day", "The bottom line is".
- End by saying the last thing you have to say. Stop when you're done.

### 8. Rhetorical Questions as Section Openers
- AI loves "So what does this mean for your business?" / "But why does this matter?"
- Use sparingly (once per article maximum). Never as a structural device for every section.

---

## Required Techniques (Do These)

### 1. Vary Sentence Length Deliberately
- Alternate between long sentences (20-30 words) and short ones (3-8 words).
- Throw in an occasional fragment. "Not always, though." / "A big difference."
- Humans don't write sentences that are all 15-20 words long. Break the rhythm.

### 2. Be Specific, Not Abstract
- Replace vague claims with concrete details: numbers, names, examples, timeframes.
- Bad: "This can significantly improve your operations."
- Good: "One client cut their order processing from four hours to twenty minutes."

### 3. Use an Imperfect Voice
- Start sentences with "And" or "But". Use contractions ("don't", "it's", "they'll").
- Write the occasional aside in parentheses (like this one).
- Use informal connectors: "The thing is,", "Honestly,", "In practice,", "Here's the catch."
- Use "which" loosely, even when a grammar purist would say "that".

### 4. Uneven Paragraph Lengths
- Some paragraphs should be 1-2 sentences. Others 4-5.
- Never write five paragraphs of identical length. That's a dead giveaway.

### 5. Domain-Specific Vocabulary
- Use jargon and abbreviations that someone in the field would actually use, without over-explaining them.
- If writing for EDI: say "850", "ASN", "implementation guide", "chargeback" naturally.
- Don't define every term unless the audience genuinely wouldn't know it.

### 6. Show Opinion and Hedging (Asymmetrically)
- Humans have opinions: "The honest answer is...", "This part tends to surprise people.", "That's overkill for most small shops."
- Hedge unevenly. Be direct about some things and uncertain about others. AI hedges uniformly.

### 7. Imperfect Structure
- Not every section needs the same depth. Some topics get two paragraphs; others get five.
- Skip the neat "intro paragraph, 3 body sections, conclusion" template.
- Let the structure follow what you actually need to say, not a symmetric outline.

### 8. Concrete Connective Tissue
- Instead of generic transitions, connect paragraphs with specific references to what was just said.
- "That rejection rate is why..." (refers back to a number you mentioned)
- "The implementation guide I mentioned..." (refers to a prior paragraph)

---

## Self-Check Before Delivering

Run this mental checklist on every piece of writing:

1. **Em-dash scan**: Search for `—`. Remove all of them.
2. **Triple scan**: Look for "X, Y, and Z" patterns. Break them up.
3. **Opener variety**: Read just the first word of each paragraph. If more than two start the same way, rewrite some.
4. **Sentence length variance**: Read aloud. If it sounds like a metronome, add some short punches and one long winding sentence.
5. **Filler word scan**: Ctrl+F for "comprehensive", "streamline", "seamless", "leverage", "innovative", "robust", "utilize", "facilitate", "elevate", "empower". Remove all hits.
6. **Transition scan**: Check for "Moreover", "Furthermore", "In addition", "That said". Replace with nothing or casual connectors.
7. **Conclusion check**: Does the last paragraph start with "In conclusion" or summarize everything? Cut it or replace with a forward-looking final thought.
8. **Paragraph length check**: Are all paragraphs roughly the same size? Vary them.
9. **Would a person say this out loud?** If a sentence sounds weird spoken aloud, rewrite it.

---

## Tone Calibration by Context

| Context | Voice | Example Calibration |
|---------|-------|-------------------|
| Blog post (B2B) | Knowledgeable colleague explaining their work | Conversational but not sloppy. Specific. Uses industry terms without fanfare. |
| Marketing web copy | Clear and direct, like a good salesperson | Short sentences. Benefits over features. No hype words. |
| Email draft | Natural speaking voice | Contractions, incomplete sentences OK. Get to the point. |
| Bio / About page | Third-person but warm | Avoid listing accomplishments like a resume. Tell a short story. |
| Technical article | Practitioner sharing what they learned | Show your work. Mention what went wrong. Be honest about tradeoffs. |

---

## Example Rewrites

### AI-sounding (bad):
> We provide comprehensive EDI integration services that streamline your operations, reduce errors, and scale with your business. Our team of experts leverages cutting-edge technology to deliver seamless B2B solutions tailored to your unique needs.

### Human-sounding (good):
> We set up EDI connections between your ERP and your trading partners. Most of what we do is mapping: taking the purchase orders, invoices, and ship notices that your partners expect and making sure they match what your system actually sends. When something breaks at 2 AM because a retailer changed their spec, we're the ones who fix it.

---

## When This Skill Activates

This skill applies whenever you are writing prose that a human will read as authored content. It does NOT apply to:
- Code comments (keep those minimal per CLAUDE.md)
- Commit messages (follow Conventional Commits format)
- Technical documentation like READMEs or architecture docs (clarity over voice)
- JSON, YAML, or configuration files
- Test descriptions

It DOES apply to:
- Blog posts and articles
- Website marketing copy (headlines, descriptions, CTAs, about pages)
- Email drafts
- Social media copy
- Client-facing documents
- Any text the user explicitly asks to "write" or "draft"
