# Testing Kindled Deep

The first real two-PC playtest found five game-breaking co-op bugs that every
automated test had passed. Each had a different cause, and all of them showed
on someone's screen. Unit tests and bots checked the host's simulation. Nobody
looked at the guest's picture, pressed the real keys, or stayed on a floor
long enough for a race to show. These are the rules that came out of that, and
the tools that make them cheap.

## Rules

For any change that touches co-op (networking, scenes, UI, input, anything a
guest draws):

1. Test the logic automatically (`tests/`, headless).
2. Run separate host and guest processes over the real network
   (`tools/dev/e2e.sh`). A second Kindled simulated inside one process does not
   count.
3. Drive them with real input: the bound keys and the mouse, through Input
   (`src/dev/scenario.gd`). Calling `prop.interact()` or `Game.descend()`
   directly skips the very paths that broke.
4. Capture every machine's screen at the same moment (`Net.dev_shot`), and look
   at the captures - each side's. The host's picture proves nothing about the
   guest's.
5. Check transitions: floors, the sanctuary and back, joining, leaving.
6. Use more than two players where it matters (`e2e.sh 4`).
7. Play a whole expedition: sanctuary, proposal, depths 1-3, home, again.
8. Run solo too (`tests`, `uismoke`, an autopilot run, `scenario=talk`).
9. Repeat under simulated links (`e2e.sh 4 journey typical moderate stress`):
   races between floors only show with latency.
10. Report what was and was not checked: unit-tested, run as separate
    processes, captured and viewed, played by a human. Do not call co-op
    working from one machine's logs.

Localhost is not the internet, and simulated links are not routers, NAT or
Steam's relay. A human pair on two PCs is still needed (see below).

## Tools

| Tool | What it does |
|---|---|
| `tools/dev/run_tests.sh` | Unit and simulation tests (headless). Fails on any script error. |
| `-- uismoke profile=smoke.json` | Opens every screen and presses its buttons, including synthetic gamepad checks. |
| `tools/dev/e2e.sh [n] [scenario] [netsim...]` | n real windows (host + guests), fresh dev profiles, distinct outfits, the scenario played on each. Prints every check, every failure and every script error, then runs the comparison. |
| `tools/dev/e2e_compare.py logs...` | From the `[probe]` lines: how far each machine's picture of every other Kindled is from where its owner had it, per sanctuary and floor (p50 / p95 tiles), and any FROZEN stretch (the owner walked more than 2 tiles in 2 s, the picture stayed put, and they ended apart). Teleports such as being drawn into a room are not counted. |
| `tools/dev/e2e_recovery.sh` | A guest killed mid-expedition and restarted (it must take its seat back), then the host killed (the guest must bank its depth checkpoint once). |
| `tools/dev/coop_local.sh`, `netsim_matrix.sh` | Bot-only co-op runs and the measured network table in NETWORK.md. |
| `-- showcol` | Every tile a Kindled cannot walk onto drawn red on the floor (pits blue), each Kindled's box green: compare footprints with the art. |
| `-- capture=<name> frames=N quit` | One capture of the real rendered window. F12 in play. |

### Scenarios (`-- scenario=<name> role=host|guest`)

- `journey`: the whole evening.
  - **Party and sanctuary.** Host and join through the party screen (real
    clicks), meet in the sanctuary, check each Kindled is drawn in its
    owner's armour, and hide a helm live.
  - **Talking.** Talk to the Keeper with F, by mashing F, with Esc and with a
    click, and accept a resident's request.
  - **The expedition.** Propose it at the gate; a guest declines, the host
    withdraws, proposes again, and everyone accepts with Y.
  - **Below.** On depth 1 every foe must be drawn and a sealing room draws
    in a teammate safely. At depths 2 and 3 everyone walks on their own keys
    while the others check they move.
  - **Home and again.** A Hearthcall home, then a second expedition.
- `bestiary`: the host raises every kind of foe beside the party (all 25
  kinds, elites of every affix, a Grudge, the three guardians), and fells them.
  Each guest checks every one was drawn whole and is gone afterwards.
- `stairs`: just the stairs with the dev party. `stay=30` stays on depth 1
  first. It found the "frozen after the stairs" race: the old code fails it
  under `netsim=moderate`.
- `talk`: the dialogue checks alone (solo).
- `partyesc`: the party screen opened, hosted from, closed with Esc.

A scenario prints `[scenario] ok/FAIL ...` lines, `[probe] {...}` lines four
times a second, and ends with `[scenario] RESULT <role>: n passed, m failed`
(exit code 1 on a failure). Captures go to `captures/e2e/`.

## Human playtest on two PCs

Two people, each on their own PC. For a LAN game, both on the same network:

1. **Host.** A: main menu > Play Together > Host. B: Play Together > Join by
   Address, then type the address A's party screen shows. Over Steam: A
   chooses Host on Steam; B uses Join a Friend, or accepts A's invite.
2. **The sanctuary.** You both stand in A's camp and see each other, each
   in your own armour. Check:
   - B changes gear or wardrobe (hide a helm): A sees it within a second.
   - Each talks to the Keeper and to a resident with a "!". F, a click and
     Esc each work once; the world stays visible behind the words; nothing
     stays dark.
   - Walk into each other and through a crowd at the gate: nobody gets
     stuck.
3. **The expedition.** A walks to the gate and proposes. B gets the card
   wherever they are, even in the satchel. B presses N: A's card shows "Not
   now". A presses N to withdraw, proposes again, B presses Y: a 3 s
   countdown, then you both go down together.
4. **Depth 1.** B stays back while A enters a fight room. Check:
   - B is drawn in just inside the door A used, on open floor, and can
     move at once.
   - Both of you see every foe as a sprite, with nameplates and bars on
     elites.
5. **The stairs.** After a few minutes on depth 1, take the stairs (both
   press Y). On depth 2, each walks somewhere different: each must see the
   other move. Repeat at depth 3.
6. **Home.** Hearthcall home, then propose a second expedition.
7. **Drops.**
   - B quits mid-floor and starts again: B must take its seat back.
   - A quits mid-floor: B tries for 30 s, then brings home what it carried
     into that depth.

Note anything odd with the F3 overlay on: its round trip, loss and
corrections help diagnose it. Keep both machines' `[net]` and `[steam]` log
lines (in the `--verbose` console, or run from a terminal).
