#define LUA_LIB

#include "skynet.h"
#include "skynet_malloc.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static uint8_t *map = NULL;  // Use bits for occupancy tracking
static int map_width = 0;
static int map_height = 0;
static int map_byte_size = 0;

static int l_init(lua_State *L) {
    map_width = luaL_checkinteger(L, 1);
    map_height = luaL_checkinteger(L, 2);
    map_byte_size = ((map_width * map_height) + 7) / 8;  // Calculate required bytes
    if (map) {
        skynet_free(map);
    }
    map = skynet_malloc(map_byte_size);
    memset(map, 0, map_byte_size);  // Initialize all bits as unoccupied
    return 0;
}

static inline int isindex(int x, int y) {
    return y * map_width + x;
}

static inline void set_bit(uint8_t *map, int index, int value) {
    int byte_index = index / 8;
    int bit_index = index % 8;
    if (value) {
        map[byte_index] |= (1 << bit_index);  // Set the bit
    } else {
        map[byte_index] &= ~(1 << bit_index);  // Clear the bit
    }
}

static inline int get_bit(uint8_t *map, int index) {
    int byte_index = index / 8;
    int bit_index = index % 8;
    return (map[byte_index] & (1 << bit_index)) != 0;
}

static int l_set(lua_State *L) {
    int x = luaL_checkinteger(L, 1);
    int y = luaL_checkinteger(L, 2);
    int w = luaL_checkinteger(L, 3);
    int h = luaL_checkinteger(L, 4);
    if (x < 0 || y < 0 || x + w > map_width || y + h > map_height) {
        lua_pushboolean(L, 1);  // Out of bounds treated as overlap
        return 1;
    }
    for (int i = y; i < y + h; i++) {
        for (int j = x; j < x + w; j++) {
            set_bit(map, isindex(j, i), 1);  // Mark cell as occupied
        }
    }
    return 0;
}

static int l_clear(lua_State *L) {
    int x = luaL_checkinteger(L, 1);
    int y = luaL_checkinteger(L, 2);
    int w = luaL_checkinteger(L, 3);
    int h = luaL_checkinteger(L, 4);
    for (int i = y; i < y + h; i++) {
        for (int j = x; j < x + w; j++) {
            set_bit(map, isindex(j, i), 0);  // Mark cell as unoccupied
        }
    }
    return 0;
}

static int l_check(lua_State *L) {
    int x = luaL_checkinteger(L, 1);
    int y = luaL_checkinteger(L, 2);
    int w = luaL_checkinteger(L, 3);
    int h = luaL_checkinteger(L, 4);
    if (x < 0 || y < 0 || x + w > map_width || y + h > map_height) {
        lua_pushboolean(L, 1);  // Out of bounds treated as overlap
        return 1;
    }
    for (int i = y; i < y + h; i++) {
        for (int j = x; j < x + w; j++) {
            if (get_bit(map, isindex(j, i))) {
                lua_pushboolean(L, 1);  // Overlap found
                return 1;
            }
        }
    }
    lua_pushboolean(L, 0);  // No overlap
    return 1;
}

int luaopen_mapblock(lua_State *L) {
    luaL_Reg l[] = {
        {"init", l_init},
        {"set", l_set},
        {"clear", l_clear},
        {"check", l_check},
        {NULL, NULL}
    };
    luaL_newlib(L, l);
    return 1;
}