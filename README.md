# router-game

A [pipe-mania][1] like game, where you'd lay down paths on a grid to get the goblets from start to destinations.  The goblets are of different levels where some move faster, some explode, etc.  It's mobile/touchscreen friendly game.

This is actually a mini-game to my actual W.I.P. game [tdcraft-godot][2], similar to my other mini-game [on-my-way][3]

[1]: https://en.wikipedia.org/wiki/Pipe_Mania
[2]: https://github.com/HidekiAI/tdcraft-godot
[3]: https://github.com/HidekiAI/on-my-way

## Technical Design
- Want to use Godot4 TileMap (grid/square view) as a starting point
    - Initial view is top-down like puzzle games do
    - Possibly switch over to Isometric view of the TileMap, and if that does not work, maybe even go 3D instead of 2D to do Isometric
- Game mechanics should be portable in a sense that it's path-laying library can be used for the real game (see [tdcraft-godot] project)

## Game Design
- A pathway/road laying game in which your bots and heroes follow the paths you'd lay down
- Types of games - There are two kinds of games (settings):
    - Attempt to mimic the original [pipe-mania] like game, in which you'd get a queue of tile-cells in which you'd place at any cell (unoccupied and/or preoccupied, as long as it's not at the starting cell) and when the timer reaches 0, the stream will begin to flow down the laid cells and you'd race to make sure that the paths of the laid cells will continue to flow as long as possible.
    - The second (custom) game type is more of in which on the grid, there will be a static tower in which your heroes and bots that can counter attack can fire back if needed.  The paths you'd lay down is similar random queue as pipe-mania-like game, but you'd want to carefully lay the path down so that the correct bots can counter attach the towers on its ways to the goal.
        - Not just the towers, but starting and ending are static as well.
        - The endpoint is usually the resource, while the startpoint is usally the warehouse that will hold that resource (i.e. startpoint is a lumber mill, and endpoint is the forest).  Because start/end has a means and purpose, the whole paths are round-trip to get FROM the startpoint to endpoint, then BACK to startpoint as to carry the resources back.
