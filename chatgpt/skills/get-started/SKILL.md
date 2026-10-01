---
name: get-started
description: Set up Audivo after it is installed. Use right after installation, or when the user asks how to start with Audivo or whether it is connected.
---

# Getting started with Audivo

Help the user see that Audivo is connected and what to ask it.

1. Call `list_transcripts`. It spends nothing and confirms the connection.
   - If it fails because the user is not signed in, ask them to connect
     Audivo from the plugin's settings and sign in with their Audivo
     account (or create one at audivo.dev).
   - If it works, the library appears. Say whether they have transcripts
     already.
2. In two or three sentences, say what Audivo does: it transcribes podcast
   episodes from public feeds, shows them in a reader with timestamps and
   search, and keeps them in a library they can open from the sidebar.
   Transcribing spends credits from their Audivo account; finding shows and
   reading transcripts do not.
3. Offer two example requests, such as:
   - "Transcribe the latest episode of Hard Fork and summarize it."
   - "Find the Acquired episode about Costco and quote what they said
     about membership fees."

Do not transcribe anything during setup unless the user asks for an episode.
