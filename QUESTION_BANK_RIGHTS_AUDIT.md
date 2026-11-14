# Question Bank Rights and Provenance Audit

Audit date: 2026-11-14

## Scope and verified counts

- Total questions in `data/questions.json`: 5,643.
- Questions already carrying explicit third-party provenance: 1,427.
- Remaining questions without per-question provenance before this audit: 4,216.
- Structural checks on the current bank: 5,643 questions inspected; no duplicate question text detected by normalized exact-text comparison; all inspected entries had exactly four distinct answer choices, a valid integer correct-answer index (0–3), and a non-empty explanation.

## Repository-history findings for the 4,216 questions

The repository history shows these question batches were added directly to this project in project-specific commits, rather than imported as a named third-party question-bank dataset:

- Initial offline Arabic quiz bank: `27e6ca0271c4af9f807450e92d68699f9513e266` (10 initial questions).
- Science and country-culture expansion: `f918d62f4e9fd7b7d2d4113891a3331119eadbcd`.
- Diversified Algeria science and culture batch: `568149a47a87dea5c5c32e9b8a7fbde81de66ee5`.
- Tunisia, Libya, Egypt and Morocco expansion: `e9b6c403d1fbb9de5116acebb6ded07fbd4b0468`.
- Eight-country expansion: `f9c71d23cd896ce53bdffd1b81bc1796b3fdfaa3`.
- France, Japan, India, Brazil, Turkey, China, Nigeria and Ethiopia expansion: `2e87bcac1e3ea0440c63c2a964aa15cc4e6e60d6`.
- Spain, Italy, Germany, UK, Mexico, Argentina, Kenya and South Africa expansion: `70359267261574d6f2f431a10f9ed2f9344fce2a`.
- Fifteen-country expansion: `96ee148b06daabe537ebca21952ef592f0160d49`.
- Fourteen-country expansion: `a6161931ff64763b3c7194221f4ea70216d861dc`.
- Fifteen-country European expansion: `c5f91459fba82948c733e6fb69e038ab5902b753`.
- Religion and belief questions: `80e24e454d7c77bc6ff837eb867c40fa93af15e4`.
- Country heritage, religion and global science expansion: `d20d1c6c7541753bf04c2bfb3355b6f98592af61`.
- Additional country/science batches: `7b2220a0f14731f6aa5fad6eb594fb983489d5fa` and `074cdf81676aa954ff1cfdff8e466fb4a8eb4cd7`.
- Notable-people batch: `52ef04bc47294987fa6363da55adeaa08fe46082`.

These commits support the conclusion that the 4,216 entries were authored/assembled for the Challenge project. The repository history does not identify a third-party question-bank source for those batches.

## Important limitations

- This is a provenance review, not a legal opinion or a guarantee of Google Play acceptance.
- A commit authored in this repository does not by itself prove that every fact is correct or that no question was unintentionally too close to a third-party wording.
- Factual statements should be checked against reliable references. Facts and short factual formulations can raise different legal issues depending on jurisdiction and the source wording.
- The 1,427 QuizBattle-derived questions retain their separate MIT/source metadata and are covered by `THIRD_PARTY_NOTICES.md`.
- Before publication, retain the repository history and this audit file as supporting records; review images, maps, fonts, audio, libraries and store assets separately.

## Current publication recommendation

The 4,216 project-batched questions have no third-party question-bank attribution recorded in the repository history reviewed here. They may be treated as project-authored content for the next review stage, but should not be described as fully legally cleared until factual sources, similarity, and any external assets are checked.
