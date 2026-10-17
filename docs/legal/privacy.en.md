> **DRAFT, NOT REVIEWED BY A LAWYER.** Do not publish. Version 0.1, 2026-10-16. Bracketed items are to be completed (see `README.md`). The Spanish version (`privacidad.es.md`) is the reference text; this one must say the same.

# Lumbre Privacy Policy

Effective [DATE].

Lumbre is an app for saving ideas and connecting them. To work, it needs to store what you write and send it to an artificial intelligence. This policy explains what data we keep, why, who we share it with, how long we keep it and how you control it.

## 1. Who is responsible

The controller of your data is [OWNER], [TAX ID], [ADDRESS], Argentina ("Lumbre", "we"). For any question about your data: [PRIVACY EMAIL].

This policy covers the Lumbre app for iOS and Android, the website [DOMAIN], the waitlist and the web demo.

## 2. What we collect

**Your account.**
- Your email, so you can sign in with a link or a code.
- If you sign in with Apple or Google, what they send us: your email (or Apple's private relay email) and sometimes your name and profile picture. We don't use the name or picture for anything.
- If you continue as a guest, we don't ask for any data: an anonymous account is created.

**Your profile.** The creative profiles you choose, the time you want your daily spark, your time zone, your language and your plan (free or Pro). We don't use your location: the app reads the time zone from your phone.

**What you save in Lumbre.**
- Your neurons: the text of each idea, its title, principle and category.
- The source: its type (text, voice, link, image, PDF), the link and page title, and any excerpt you highlighted (up to 500 characters).
- The full text of what you captured, for 30 days only (see 6).
- If you save a photo or screenshot, a reference to show it again on your phone. The photo stays on your phone.
- A numeric representation of each idea (an "embedding") used for search and for choosing which ideas to connect. It can't be read as text.
- Your sparks, whether you saved or dismissed them, and the reason when you tap "Not useful".
- Your circuits and your conversations with the planner.
- Any reports you make about AI-generated content.

**Files.** If you send an image or a PDF to be conceptualized, it goes to temporary storage, is processed and **deleted right away**, whether processing succeeded or not. We don't keep your files, audio or full web pages.

**Voice.** Voice dictation is transcribed on your phone by the operating system. Only the text reaches Lumbre.

**App usage.** Usage events such as "saved a neuron" or "opened a spark", with your user ID, the type of action, counts in ranges and technical data (platform, version, language, theme). **They never include what you write**: no text, titles, links, searches or messages.

**Errors.** When the app fails, a technical crash or error report (device, OS, app version, where it failed), without the content of your notes.

**Notifications.** The token Apple or Google assigns to your phone so it can receive the daily spark.

**Purchases.** If you subscribe to Pro, Apple or Google processes the payment. We never see your card: we receive from them (through RevenueCat) the subscription type, status and dates.

**AI usage.** For each AI call we log the feature, model, number of tokens, cost and latency, to control costs and abuse. We don't log the content.

**Waitlist and web demo.** If you join the waitlist, we store your email, your referral code, who invited you (if anyone), your language and which campaign brought you. In the web demo, the two ideas you paste are sent to the AI to create the spark and **are not stored**; we only record that the email already used today's demo. To prevent abuse we keep your IP address in hashed form (it can't be recovered) for one day.

## 3. Why we use it

| Purpose | Data | Legal basis |
|---|---|---|
| Providing the service: saving, conceptualizing, sparks, search, planner, syncing across devices | Account, profile, your content | Performance of the contract (the terms) and your consent to AI processing (section 4) |
| Sending your spark at the time you chose | Push token, time, time zone | Performance of the contract; you can turn notifications off on your phone |
| Charging for and activating Pro | Purchases | Performance of the contract |
| Enforcing plan limits and preventing abuse | Quotas, AI call log, hashed IP (web) | Legitimate interest in a working, abuse-free service |
| Moderating AI-generated content | Reports | Legitimate interest and app store requirements |
| Improving the app | Usage events, errors | Legitimate interest (no content, no advertising) |
| Telling you about the launch | Waitlist | Your consent when you sign up |

We don't use your data for advertising, we don't sell it, we don't build profiles for third parties and we don't track you across apps or websites. We don't train our own AI models on your content.

## 4. Artificial intelligence

Lumbre uses **Claude**, by **Anthropic, PBC** (United States), to:
- **Conceptualize:** turn what you save (text, a link, an image or a PDF) into a neuron with a title, thesis and principle.
- **Generate sparks:** from two of your neurons and your creative profile.
- **The planner** (Pro): your messages, the spark, the two neurons behind it and your creative profile.

To search and pair ideas, the text of each neuron and each search is sent to an embeddings provider, [EMBEDDINGS PROVIDER] (United States), which turns it into numbers.

Before sending your content to the AI, the app asks for your permission. If you decline, you can still use Lumbre to save ideas, but they won't be conceptualized and no sparks will be generated. You can change your answer at any time in Profile › Privacy and data.

Only what each task needs is sent. Under its current commercial terms, Anthropic does not use data received through its API to train its models and keeps it for a limited time for safety purposes. [VERIFY current wording and retention period before publishing.]

Sparks and planner replies are produced by an AI: they can be inaccurate, incomplete or obvious. Use them as a starting point, not as professional advice.

## 5. Who we share data with

Only with providers that process it on our behalf to run the service, under contracts that require them to protect it:

| Provider | Purpose | Location |
|---|---|---|
| Supabase | Database, authentication and temporary storage | [PROD REGION] |
| Anthropic | AI: conceptualizing, sparks, planner, web demo | United States |
| [EMBEDDINGS PROVIDER] | Embeddings for search and pairing | United States |
| PostHog | Usage analytics, no content | European Union |
| Sentry | Error reports | United States |
| RevenueCat | Subscription management | United States |
| Apple and Google | Sign-in, payments and notifications | United States |
| [EMAIL PROVIDER] | Sign-in and waitlist emails | [COUNTRY] |

We may also disclose data when a competent authority requires it by law, or to defend our rights against unlawful use of the service. If Lumbre changes ownership, your data passes to the new controller under this same policy, and we'll tell you beforehand.

## 6. How long we keep it

| Data | Period |
|---|---|
| Files sent for conceptualizing (images, PDFs) | Deleted as soon as they are processed |
| Full text of each capture | 30 days; after that only the conceptualized neuron remains |
| Your account and everything you saved | Until you delete it or delete your account |
| Guest accounts | Deleted automatically after 30 days without use |
| AI usage and subscription logs | Kept for accounting and cost control, without your user ID once your account is deleted |
| Error reports | Up to 90 days |
| Waitlist | Up to [6 months] after launch, or until you unsubscribe |
| Hashed IP (web) | 1 day |
| Backups | Up to [7] days; deleted data disappears from them within that period |

## 7. Your rights

At any time you can:
- **Export your data** from the app (Profile › Privacy and data › Export my data): a JSON file with your profile, categories, neurons, sparks, circuits and planner conversations.
- **Correct** your neurons, categories and profile in the app.
- **Delete** a neuron, spark or circuit in the app.
- **Delete your account** in the app (Profile › Privacy and data › Delete account) or at [DOMAIN]/delete-account. Your account and everything you saved are deleted immediately and permanently, including your profile in our analytics tool. If you have a subscription, cancel it in your Apple or Google account: deleting your Lumbre account doesn't cancel it.
- **Withdraw consent** to AI processing in the app.
- **Request access, rectification, erasure, objection or portability**, or ask anything, by writing to [PRIVACY EMAIL]. We reply within one month at the latest.

**European Union and United Kingdom.** You also have the right to restrict processing and to lodge a complaint with your local data protection authority. [EU representative, if required: to be defined with counsel.]

**Argentina.** Rights under Law 25,326 apply as described in the Spanish version. The Agency for Access to Public Information is the supervisory authority.

## 8. International transfers

Your data is processed outside your country, in the countries listed in section 5. Where a provider is in a country without an adequate level of protection, we rely on the safeguards they offer (standard contractual clauses). [Review with counsel.]

## 9. Security

Everything travels encrypted (HTTPS). Each user can only read their own data (database access rules, tested automatically). AI keys live only on our servers, never in the app. Technical logs don't include the content of your notes. Your session is stored in your phone's encrypted keychain. No system is infallible: if a breach affects you, we'll notify you and the authorities as required by law.

## 10. Children

Lumbre is not intended for anyone under 16 and we don't knowingly collect data from them. If you know a minor has given us data, write to us and we'll delete it.

## 11. Changes

If we change this policy, we'll publish the new version with its date. If the change is significant (for example, a new AI provider or a new use of your data), we'll tell you in the app before it applies and ask for your consent again if needed.

## 12. Contact

[OWNER] · [ADDRESS] · [PRIVACY EMAIL]
