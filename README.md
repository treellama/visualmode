Visual Mode Plugin
by Jon Irons and Gregory Smith

What is this?
=============

The Visual Mode plugin lets you texture levels in the engine, much like
Forge's visual mode did.

How do I use it?
================

In Aleph One, go to your Environment preferences, and enable the
Visual Mode plugin. Now, choose the map you want to texture. Start the
game.

Across the top of the screen, you'll see some descriptive labels that
will help you. You can switch between texture and move modes by
pressing the action key. You can get more options by holding down the
microphone key, or switching to overhead map mode, or both.

If you apply the wrong texture, press and hold the microphone key, and
then press the action key, to undo.

To save your level, bring up the console by pressing the console key, and type:

    .save level Levelname.sceA

When you save successive times, you only need to type

    .save level

and it will overwrite your previous save.

Since Aleph One is a little sloppy about clearing out the data in
levels it exports, I recommend opening and resaving in Weland when
finished texturing.

Congratulations, you now know *everything you need* to know about Visual
Mode!

FAQ
===

Q: How do I switch textures?
A: In texture mode, hold down the mic key and press prev or next weapon

Q: Does it work in co-op?
A: Yes! Unzip the plugin, and select the Visual Mode.lua file inside
as your netscript. Since Visual Mode uses the mic key, you'll have to
resort to text chat.

Q: How do I apply transparent textures?  
A: In texture mode, switch to the overhead map. Press the secondary
trigger to change between solid and transparent apply

Q: How do I create rechargers, terminals, pattern buffers, and switches?
A: Apply one of the first 5 textures. Visual mode will enter a device
mode, where you can choose which control panel you want (only control
panels that are appropriate for the texture you selected will be
shown). Then press the primary trigger to save, or secondary to cancel
without saving changes to the control panel.

Warning: .save level will save the tag switches in their current
position, so make sure if you need to set them to move around the map,
that you reset them before you save. Platform and light switches will
assume the correct position when the level loads, so you don't have to
worry about them.

