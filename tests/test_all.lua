-- Comprehensive test suite for physical-keyboard.nvim
-- Run with: nvim --headless -u tests/test_all.lua

vim.opt.rtp:prepend(vim.fn.getcwd())

local LayoutHandler = require("physical-keyboard.layout.LayoutHandler")
local Layout = require("physical-keyboard.layout.Layout")
local Message = require("physical-keyboard.utils.Message")

local tests_passed = 0
local tests_failed = 0

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        print("[FAIL] " .. msg .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        tests_failed = tests_failed + 1
        return false
    end
    return true
end

local function assert_true(val, msg)
    if not val then
        print("[FAIL] " .. msg .. ": expected true, got " .. tostring(val))
        tests_failed = tests_failed + 1
        return false
    end
    return true
end

local function pass(msg)
    print("[PASS] " .. msg)
    tests_passed = tests_passed + 1
end

-- Helper: count all PKB mappings for a layout across all modes and both global/buffer-local
local function count_pkb_mappings(layout_name, modes)
    local count = 0
    modes = modes or {"n", "i", "o", "v", "t"}
    for _, mode in ipairs(modes) do
        local gs = vim.api.nvim_get_keymap(mode)
        for _, m in ipairs(gs) do
            if m.desc and m.desc:find("PKB.*" .. layout_name) then
                count = count + 1
            end
        end
    end
    return count
end

-- Test 1: Basic character mappings
do
    print("\n=== Test 1: Basic character mappings ===")
    local h = LayoutHandler.new(Message.new())
    local l = Layout.new()
    l:setName("t1")
    l:setActive(true)
    l:setVimMode({"n", "i", "o"})
    l:setFormMapOptions({})
    l:setMap({["ф"]="a", ["и"]="b"})
    assert_true(h:registerLayout(l), "register layout")
    assert_true(h:enableLayout("t1"), "enable layout")

    local count = count_pkb_mappings("t1", {"n", "i", "o"})
    if assert_eq(count, 6, "mappings created") then
        h:disableLayout("t1")
        count = count_pkb_mappings("t1", {"n", "i", "o"})
        if assert_eq(count, 0, "mappings removed") then
            pass("Basic mappings: 6 created, 6 removed")
        end
    end
end

-- Test 2: auto_modifiers (Ctrl, Alt, Shift)
do
    print("\n=== Test 2: auto_modifiers ===")
    local h = LayoutHandler.new(Message.new())
    local l = Layout.new()
    l:setName("t2")
    l:setActive(true)
    l:setVimMode({"n", "t"})
    l:setFormMapOptions({"auto_modifiers"})
    l:setMap({["о"]="o"})
    assert_true(h:registerLayout(l), "register layout")
    assert_true(h:enableLayout("t2"), "enable layout")

    local count = count_pkb_mappings("t2", {"n", "t"})
    -- 7 variants (base, C, A, S, C-A, C-S, A-S) × 2 modes = 14
    if assert_eq(count, 14, "modifier mappings created") then
        h:disableLayout("t2")
        count = count_pkb_mappings("t2", {"n", "t"})
        if assert_eq(count, 0, "modifier mappings removed") then
            pass("Modifier mappings: 14 created, 14 removed")
        end
    end
end

-- Test 3: exclude_insert
do
    print("\n=== Test 3: exclude_insert ===")
    local h = LayoutHandler.new(Message.new())
    local l = Layout.new()
    l:setName("t3")
    l:setActive(true)
    l:setVimMode({"n", "i", "o"})
    l:setFormMapOptions({"exclude_insert"})
    l:setMap({["ф"]="a"})
    assert_true(h:registerLayout(l), "register layout")
    assert_true(h:enableLayout("t3"), "enable layout")

    -- Should NOT have insert mode mappings
    local i_count = 0
    for _, m in ipairs(vim.api.nvim_get_keymap("i")) do
        if m.desc and m.desc:find("PKB.*t3") then i_count = i_count + 1 end
    end
    assert_eq(i_count, 0, "no insert mode mappings")

    -- Should have n and o
    local n_count = 0
    for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.desc and m.desc:find("PKB.*t3") then n_count = n_count + 1 end
    end
    assert_eq(n_count, 1, "normal mode mapping exists")

    h:disableLayout("t3")
    local count = count_pkb_mappings("t3", {"n", "i", "o"})
    if assert_eq(count, 0, "all mappings removed") then
        pass("exclude_insert: correct modes used, all removed")
    end
end

-- Test 4: Combined options
do
    print("\n=== Test 4: Combined options ===")
    local h = LayoutHandler.new(Message.new())
    local l = Layout.new()
    l:setName("t4")
    l:setActive(true)
    l:setVimMode({"n", "i", "o", "v"})
    l:setFormMapOptions({"auto_modifiers", "auto_capital"})
    l:setMap({["ф"]="a", ["и"]="b"})
    assert_true(h:registerLayout(l), "register layout")
    assert_true(h:enableLayout("t4"), "enable layout")

    local count = count_pkb_mappings("t4", {"n", "i", "o", "v"})
    if count > 0 then
        print("  Created " .. count .. " combined mappings")
        h:disableLayout("t4")
        count = count_pkb_mappings("t4", {"n", "i", "o", "v"})
        if assert_eq(count, 0, "all combined mappings removed") then
            pass("Combined options: all removed")
        end
    else
        print("[FAIL] No mappings created")
        tests_failed = tests_failed + 1
    end
end

-- Test 5: Multiple layouts independent
do
    print("\n=== Test 5: Multiple layouts ===")
    local h = LayoutHandler.new(Message.new())
    local l1 = Layout.new()
    l1:setName("t5a")
    l1:setActive(true)
    l1:setVimMode({"n"})
    l1:setFormMapOptions({})
    l1:setMap({["ф"]="a"})
    local l2 = Layout.new()
    l2:setName("t5b")
    l2:setActive(true)
    l2:setVimMode({"n"})
    l2:setFormMapOptions({})
    l2:setMap({["и"]="b"})
    assert_true(h:registerLayout(l1), "register t5a")
    assert_true(h:registerLayout(l2), "register t5b")
    assert_true(h:enableLayout("t5a"), "enable t5a")
    assert_true(h:enableLayout("t5b"), "enable t5b")

    local c1 = count_pkb_mappings("t5a", {"n"})
    local c2 = count_pkb_mappings("t5b", {"n"})
    assert_eq(c1, 1, "t5a mappings")
    assert_eq(c2, 1, "t5b mappings")

    h:disableLayout("t5a")
    c1 = count_pkb_mappings("t5a", {"n"})
    c2 = count_pkb_mappings("t5b", {"n"})
    assert_eq(c1, 0, "t5a removed")
    assert_eq(c2, 1, "t5b unaffected")

    h:disableLayout("t5b")
    c2 = count_pkb_mappings("t5b", {"n"})
    if assert_eq(c2, 0, "t5b removed") then
        pass("Multiple layouts: independent, all removed")
    end
end

-- Test 6: disablePlugin cleans all
do
    print("\n=== Test 6: disablePlugin ===")
    local h = LayoutHandler.new(Message.new())
    local chars = {["ф"]="a", ["и"]="b", ["с"]="c"}
    local i = 0
    for phys, en in pairs(chars) do
        i = i + 1
        local l = Layout.new()
        l:setName("t6_" .. i)
        l:setActive(true)
        l:setVimMode({"n"})
        l:setFormMapOptions({})
        l:setMap({[phys]=en})
        h:registerLayout(l)
        h:enableLayout("t6_" .. i)
    end

    local total = 0
    for j = 1, i do
        total = total + count_pkb_mappings("t6_" .. j, {"n"})
    end
    assert_eq(total, 3, "3 layouts enabled")

    h:disablePlugin()
    total = 0
    for j = 1, i do
        total = total + count_pkb_mappings("t6_" .. j, {"n"})
    end
    if assert_eq(total, 0, "disablePlugin removes all") then
        pass("disablePlugin: all cleaned")
    end
end

-- Test 7: Large layout (simulating user's ru-en)
do
    print("\n=== Test 7: Large layout ===")
    local h = LayoutHandler.new(Message.new())
    local l = Layout.new()
    l:setName("t7")
    l:setActive(true)
    l:setVimMode({"n", "i", "o", "v", "t"})
    l:setFormMapOptions({"auto_modifiers", "auto_capital", "auto_shift_specials"})
    l:setMap({
        ["ф"]="a", ["и"]="b", ["с"]="c", ["в"]="d", ["у"]="e",
        ["а"]="f", ["п"]="g", ["р"]="h", ["о"]="i", ["л"]="j",
        ["ь"]="k", ["ы"]="l", ["з"]="m", ["ш"]="n", ["щ"]="o",
    })
    assert_true(h:registerLayout(l), "register large layout")
    assert_true(h:enableLayout("t7"), "enable large layout")

    local count = count_pkb_mappings("t7", {"n", "i", "o", "v", "t"})
    print("  Created " .. count .. " mappings")

    if count > 0 then
        h:disableLayout("t7")
        local remaining = count_pkb_mappings("t7", {"n", "i", "o", "v", "t"})
        if assert_eq(remaining, 0, "all large mappings removed") then
            pass("Large layout: " .. count .. " created, all removed")
        end
    else
        print("[FAIL] No mappings created")
        tests_failed = tests_failed + 1
    end
end

-- Summary
print("\n========================================")
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
print("========================================")

if tests_failed > 0 then
    print("SOME TESTS FAILED!")
    vim.cmd("cq 1")
else
    print("ALL TESTS PASSED!")
    vim.cmd("qall!")
end
