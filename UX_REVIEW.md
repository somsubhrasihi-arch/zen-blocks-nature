# T-BLOCK player-experience review — v1.7.0

This review used the actual Flutter source, rendered phone screens and automated player interactions. It is not a physical-device playtest.

| Player friction | Change shipped |
| --- | --- |
| The guide said tapping the board rotates, but no board gesture handlers were connected. | Tapping rotates; horizontal dragging moves; a deliberate downward swipe drops. Direction locking and a distance threshold protect against accidental drops. Joystick and button controls remain available. |
| Opening settings could let blocks fall and the Sprint clock run behind the menu. | Opening settings pauses play. Closing settings leaves an explicit Resume action so the player chooses when to continue. |
| “Start playing” did not identify Classic and the mode choices had no explanation. | Play Classic is named, mode buttons include short descriptions, branding is more compact and the home screen displays the coin balance alongside the Classic best. |
| Finding the next Journey stage meant scrolling through a long list. | Continue Journey picks the next unlocked stage, or a stage where stars can improve when a world gate blocks progress. Three world selectors shorten browsing. |
| Shop previews were only small static icons, unaffordable items were unresponsive and purchases required a separate equip step. | Every item has a free board preview; effects animate unless motion is reduced. All, Owned and Affordable filters help browsing. Confirmed purchases atomically unlock and equip the item. Equipped states stay legible. |
| Results repeated achievement names in several reward rows and hid the next useful action. | Results emphasize the total and updated wallet, put the breakdown behind Reward details, and offer a direct Visit shop action. Goal progress has an in-game progress bar. |
| Background motion could be distracting and did not honor system reduced-motion preferences. | A saved Reduce motion setting and system preference stop background movement and clear bursts. Cosmetic previews show a static frame instead. |

Validation covers gesture direction and distance, actual field interaction, pausing in settings, purchase-and-equip persistence, free previews, shop filters, Journey recommendations, reduced motion and a 360×640 phone with enlarged text, alongside the existing gameplay, rewards, save and Android-build checks.

The Android application ID, existing balances, owned items, mode rules, music and themes are retained. A physical-device pass should still check thumb comfort, audio feel and stage difficulty before the store release.
