// State variables are not applicable for emulators
// For read variables, see the "update"/"init" block
state("pcsx2", "null") {}

startup
{

}

init
{
    vars.PCSX2_OFFSET = 0x20000000;
    vars.lua_State = IntPtr.Zero;   
    vars.GSGlobal = IntPtr.Zero;
    vars.BBComplete = false;

    // Boolean values to check if the split has already been hit
    vars.Splits = new HashSet<string>();
    vars.Watchers = new MemoryWatcherList
    {
    };

    // Lua hash variable name
    vars.LuaHashString = (Func<String, uint>)(str => 
    {
        // This is a copy of Lua's hash_s function
        uint l = (uint)str.Length;
        uint h = l;
        uint step = (l >> 5)|1;
        for (int i = 0; l >= step; l -= step, i += 1)
        {
            uint c = (uint)str[i];
            h = (uint)(h ^ ((h<<5)+(h>>2)+c));
        }
        return h;
    });

    vars.LuaGetVar = (Func<IntPtr, String, Tuple<IntPtr, byte>>)((t, str) =>
    {
        // luaH_getstr (custom version for Psychonauts where I don't know what's going on)
        uint hash = vars.LuaHashString(str);
        int tsize = memory.ReadValue<int>(IntPtr.Add(t, 8));

        int SIZE_OF_NODE = 0xC; // wtf where are the two TObject and next ???
        IntPtr n = (IntPtr)memory.ReadValue<int>(t);
        n = IntPtr.Add(n, vars.PCSX2_OFFSET);
        n = IntPtr.Add(n, (int)(SIZE_OF_NODE * (hash&(tsize-1))));

        // :/
        byte TYPE_STRING = 3;

        short next_index;
        IntPtr curr = n;
        while (true)
        {
            byte otype = memory.ReadValue<byte>(IntPtr.Add(curr, 0x8));
            IntPtr o = IntPtr.Add((IntPtr)memory.ReadValue<int>(curr), vars.PCSX2_OFFSET);
            uint ohash = memory.ReadValue<uint>(o);

            if (otype == TYPE_STRING && ohash == hash)
            {
                byte vtype = memory.ReadValue<byte>(IntPtr.Add(curr, 0x9));
                IntPtr vobj = (IntPtr)memory.ReadValue<int>(IntPtr.Add(curr, 0x4));
                vobj = IntPtr.Add(vobj, vars.PCSX2_OFFSET);
                return new Tuple<IntPtr, byte>(vobj, vtype);
            }

            next_index = memory.ReadValue<short>(IntPtr.Add(curr, 0xA));
            if (next_index == 0)
            {
                // nil
                return new Tuple<IntPtr, byte>(IntPtr.Zero, (byte)0);
            }

            next_index = (short)((next_index - 1) * SIZE_OF_NODE);
            curr = IntPtr.Add(curr, next_index);
        }
    });

    // Returns pointer to {Value* key, Value* value}, I think
    vars.LuaGetGlobal = (Func<String, Tuple<IntPtr, byte>>)(str =>
    {
        if (vars.lua_State == IntPtr.Zero)
        {
            return new Tuple<IntPtr, byte>(IntPtr.Zero, 0);
        }

        
        IntPtr gt = IntPtr.Add(vars.lua_State, 0x4C);
        gt = (IntPtr)memory.ReadValue<int>(gt);
        IntPtr t = IntPtr.Add(gt, vars.PCSX2_OFFSET);

        return vars.LuaGetVar(t, str);
    });
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
    if (vars.lua_State == IntPtr.Zero)
    {
        IntPtr p = (IntPtr)memory.ReadValue<int>((IntPtr)(vars.PCSX2_OFFSET + 0x3699f0));

        if (p != IntPtr.Zero)
        {
            p = IntPtr.Add(p, vars.PCSX2_OFFSET + 0x17C4);
            p = IntPtr.Add((IntPtr)memory.ReadValue<int>(p), vars.PCSX2_OFFSET);
            

            if (p != IntPtr.Zero)
            {
                vars.lua_State = p;
                print(String.Format("Found lua_State at {0:X8}", ((int)p)));
                
                uint hash_t = vars.LuaHashString("Global");
                print(String.Format("Global hash: {0:X8}", hash_t));

                var o = vars.LuaGetGlobal("Global");
                var Global = o.Item1;
                print(String.Format("Global obj: {0:X8}", (int)Global));

                o = vars.LuaGetVar(Global, "saved");
                var Global_Saved = o.Item1;
                print(String.Format("Global:saved obj: {0:X8}", (int)Global_Saved));

                o = vars.LuaGetVar(Global_Saved, "Global");
                vars.GSGlobal = o.Item1;
                print(String.Format("Global:saved:Global obj {0:X8}", (int)vars.GSGlobal));

                o = vars.LuaGetVar(vars.GSGlobal, "bLoadedFromMainMenu");
                var LMainMenu = o.Item1;
                // This is a number... whoops
                if (LMainMenu != IntPtr.Zero)
                {
                    LMainMenu = IntPtr.Add(LMainMenu, -vars.PCSX2_OFFSET);
                }
                print(String.Format("Global:saved:Global:bLoadedFromMainMenu obj {0:X8}", (int)LMainMenu));
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