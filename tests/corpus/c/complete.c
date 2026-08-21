#include <stdint.h>
#define SCALE(x) ((x) * 2)

/** Documentation <&>. */
typedef struct Entry {
    const char *name;
    uint32_t value;
} Entry;

static int render(const Entry *entry) {
    const char *text = "line\nquote=\" <&>";
    const char letter = 'x';
    return entry->value > 0xffu && text != NULL ? SCALE(2) : 0;
}
