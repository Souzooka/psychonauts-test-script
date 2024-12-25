// State variables are not applicable for emulators
// For read variables, see the "update"/"init" block
state("pcsx2", "null") {}

startup
{

}

init
{
    vars.PCSX2_OFFSET = 0x20000000;
    vars.lua_State = null;

    // Boolean values to check if the split has already been hit
    vars.Splits = new HashSet<string>();
    vars.Watchers = new MemoryWatcherList
    {
    };
}
 
start
{
    return false;
}

reset
{
    return false;
}

update
{
    // lua_State active yet? yeah I know this is garbage
    if (vars.lua_State == null)
    {
        IntPtr p = (IntPtr)memory.ReadValue<int>((IntPtr)(vars.PCSX2_OFFSET + 0x3699f0));

        if (p != IntPtr.Zero)
        {
            p = IntPtr.Add(p, vars.PCSX2_OFFSET + 0x17C4);
            p = (IntPtr)memory.ReadValue<int>(p);

            if (p != IntPtr.Zero)
            {
                vars.lua_State = p;
                print(String.Format("Found lua_State at {0:X8}", ((int)p)));
            }
        }
    }

    // Update memory watchers
    vars.Watchers.UpdateAll(game);
}

split
{
    return false;
}