# TaliaivoHistory
World of Warcraft 2.4.3 AddOn that takes informative screenshots when you level up.

Description copied from my original forum post:

A few months ago I was working on a full character history AddOn in preparation for CF, and as I was doing that, I figured out you can take cool automated commemorative screenshots when you level up. I ported just the screenshot feature to 2.4.3.

There are likely a few issues here and there, and this hasn't really been tested much on resolutions other than 2560x1440, but I figured it would be nice to post this before the server launches, so that everyone can look back at their journey from level 1.

There might be some situations when your character's model doesn't load or when the item tooltips are displayed wrong. I'm also not sure if all race/sex combos are properly positioned. It's not really as polished as I wish it was, but better have something than nothing.

I added 2 keybinds. One to take a screenshot at any time, and another to toggle the info screen. You might also want to adjust the SCREENSHOT_DELAY value in the .lua file, because otherwise your character might be blinking when the screenshot is taken. It depends on your race/sex.

Update 1: Made the frame hide and show UIParent, when you enter combat.

<img src="http://i.imgur.com/ZVLWuif.jpg" width="90%">
