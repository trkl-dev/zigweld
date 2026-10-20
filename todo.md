# Thoughts
- I wonder if file generation is actually necessary? Could I just write the source of the new binary using comptime stuff maybe?
    - I think it's not necessary. The `main` function is called differently, depending on if `init` params are set.
    - `start.zig` in stdlib sets up a custom `callMain` which conditionally calls `main` depending on various factors. This is essentially what I am trying to do. 
    - I'm not 100% sure what to do about the variable number of functions. t

# TODO:
-[] Prevent returning unhandled errors (!) like how `extern` does so. Could I leverage the same checking?
-[] Handle string input output
-[] Gracefully handle invalid types (like unsigned?)
-[] What to do about Io instantiation?
-[] Handle `void` returns


