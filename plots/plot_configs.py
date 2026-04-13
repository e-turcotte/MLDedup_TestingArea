#!/bin/env python3




# Marker: The available marker styles that can be used,
# “’.’“           point marker
# “’,’“           pixel marker
# “’o’“          circle marker
# “’v’“          triangle_down marker
# “’^’“          triangle_up marker
# “'<‘“          triangle_left marker
# “’>’“          triangle_right marker
# “’1’“          tri_down marker
# “’2’“          tri_up marker
# “’3’“          tri_left marker
# “’4’“          tri_right marker
# “’s’“          square marker
# “’p’“          pentagon marker
# “’*’“          star marker
# “’h’“          hexagon1 marker
# “’H’“         hexagon2 marker
# “’+’“          plus marker
# “’x’“          x marker
# “’D’“         diamond marker
# “’d’“          thin_diamond marker
# “’|’“           vline marker
# “’_’“          hline marker

simulator_markers = {
    "mldedup": "s",
    "comm": "v",
    "verilator": ".",
    "verilator-nodedup": "|",
    "essent": "o",
    "dedup": "x",
    "po": "*",
    "dedup-nolocality": "^"
}


simulator_linestyle = {
    "mldedup": "solid",
    "comm": "solid",
    "verilator": "solid",
    "verilator-nodedup": "dotted",
    "essent": "solid",
    "dedup": "solid",
    "po": "dotted",
    "dedup-nolocality": "dotted"
}

simulator_colors_rgb = {
    "mldedup"            : (231, 98, 84),
    "comm"               : (30, 70, 110),
    "verilator"         : (82, 143, 172),
    "verilator-nodedup" : (114, 188, 213),
    "essent"            : (0xc5, 0xe5, 0xf7),
    "po"                : (255, 208, 111),
    "dedup-nolocality"  : (247, 170, 88),
    "dedup"             : (231, 98, 84),
}

# simulator_colors_rgb = {
#     "comm"               : (231, 98, 84),
#     "verilator"         : (247, 170, 88),
#     "essent"            : (255, 208, 111),
#     "po"                : (114, 188, 213),
#     "dedup-nolocality"  : (82, 143, 172),
#     "dedup"             : (30, 70, 110),
# }

simulator_colors = {
    "comm"               : "#A1C9E1",
    "verilator"         : "#E4C455",
    "verilator-nodedup" : "#F0ABA9",
    "essent"            : "#C5E5F7",
    "dedup"             : "#BF4542",
    "po"                : "#687587",
    "dedup-nolocality"  : "#005292"
}


def convert_color(rgb_tuple):
    return "#%02X%02X%02X" % rgb_tuple

simulator_colors = {k: convert_color(v) for k, v in simulator_colors_rgb.items()}