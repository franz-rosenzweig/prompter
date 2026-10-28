<sub>[Prompter docs](README.md) › Using Prompter</sub>

# Follow, Voice and Steady

Prompter scrolls in one of three ways. You can pick one in the scripts window's toolbar, in the menu bar's Mode menu,
with the mode button on the prompter's bar, or with ⌃⌥M from anywhere, which goes through them in that order.

## Follow

Follow listens to you and moves on once you've said the words. As you talk, the speech recognizer keeps passing on
what it has heard so far, and Prompter lines up the last few words of it with the script just ahead of where you
are. When they match, it knows the word you just said, greys out everything up to it, and brings the next line up
to the reading line.

That makes it forgiving in the ways that matter:

- **Stop, and it stops.** Take a breath, answer a question, look at your slides. It waits on the line you're on.
- **Go off script, and it waits.** Words that aren't in the script don't move it, and one or two of the script's
  little words ("the", "and") on their own aren't enough to jump ahead.
- **Skip ahead, and it catches up.** Drop a sentence or two, and once it hears a few words in a row from further
  on, it jumps there. It looks about 40 words ahead.
- **A misheard word doesn't stop it.** It matches loosely: a word that's a letter off, cut short, or in the plural
  still counts, and one wrong word among several right ones doesn't matter.

What it won't do is follow you backwards. If you go back to say a line again, scroll back by hand (or use the
previous-cue button for the start of the cue) and it picks up from there.

Follow needs the microphone and speech recognition. The recognition runs on your Mac when the language allows it.
The language is your Mac's, unless you pick another in Settings › Voice › Language.

## Voice

Voice scrolls at the set speed while you're talking and stops when you're quiet, easing in and out so it doesn't
jerk. It doesn't know which words you're saying, only that you're saying something, so it's for talking from
notes rather than reading every word. It's also the one to use in a language Follow can't recognize.

Two settings matter here. **Speed** (Settings › Voice, or ⌃⌥= and ⌃⌥− from anywhere) is how fast it moves while
you talk. **Mic sensitivity** is how quiet you can be and still count as talking. Turn it up if it stops while
you're speaking softly, and down if it moves on for the air conditioner or your typing.

## Steady

Steady scrolls at the set speed until you pause it, like a classic teleprompter. It starts paused, so press play
when you're ready (click the prompter, or ⌃⌥Space). It doesn't use the microphone at all, which makes it the one
for a noisy room, or for rehearsing at a set pace. The default speed, 12 points a second, is about normal talking
speed at the default text size.

## Which one?

- Reading a script word for word: **Follow**.
- Talking from bullet points, or in a language Follow doesn't know: **Voice**.
- Rehearsing, a noisy room, or you'd rather leave the microphone out of it: **Steady**.

<sub>Next: [Shortcuts and the menu bar](shortcuts.md) →</sub>
