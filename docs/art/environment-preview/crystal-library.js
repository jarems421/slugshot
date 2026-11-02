// Original Slugshot library layouts, copied from docs/art/asset-library.html.
// Source variants and parameters retained; placement, scale and warm palette selected for this volcano.
const SLUGSHOT_CRYSTAL_DESIGNS = [
  {
    "name": "Cyan cluster",
    "deep": [
      0.02,
      0.09,
      0.15
    ],
    "bright": [
      0.42,
      0.93,
      1
    ],
    "authored": true
  },
  {
    "name": "Violet spire",
    "deep": [
      0.08,
      0.02,
      0.16
    ],
    "bright": [
      0.78,
      0.55,
      1
    ],
    "a": [
      7,
      1.1,
      7,
      1.6
    ],
    "b": [
      0.08,
      0.65,
      0.85,
      0
    ],
    "c": [
      0,
      0.3,
      0.25,
      11
    ],
    "base": [
      1.9,
      0.85,
      1.7
    ]
  },
  {
    "name": "Amber fan",
    "deep": [
      0.16,
      0.06,
      0
    ],
    "bright": [
      1,
      0.72,
      0.28
    ],
    "a": [
      9,
      2.6,
      2.9,
      1.2
    ],
    "b": [
      0.45,
      1.05,
      0.55,
      0
    ],
    "c": [
      0,
      0.2,
      0.2,
      23
    ],
    "base": [
      2.8,
      0.7,
      2.2
    ]
  },
  {
    "name": "Rose crown",
    "deep": [
      0.16,
      0.02,
      0.07
    ],
    "bright": [
      1,
      0.55,
      0.75
    ],
    "a": [
      9,
      1.7,
      3.2,
      2
    ],
    "b": [
      0.2,
      0.45,
      0.5,
      1
    ],
    "c": [
      0,
      0.3,
      0.25,
      37
    ],
    "base": [
      2.3,
      0.8,
      2.3
    ]
  },
  {
    "name": "Emerald spray",
    "deep": [
      0,
      0.11,
      0.05
    ],
    "bright": [
      0.5,
      0.95,
      0.62
    ],
    "a": [
      8,
      1,
      2.4,
      1.2
    ],
    "b": [
      0.7,
      1.15,
      0.42,
      0
    ],
    "c": [
      1,
      2.4,
      0.5,
      41
    ],
    "base": [
      1.6,
      2.1,
      1.4
    ]
  },
  {
    "name": "Frost spires",
    "deep": [
      0.06,
      0.09,
      0.14
    ],
    "bright": [
      0.88,
      0.95,
      1
    ],
    "a": [
      5,
      0.7,
      6.6,
      3.4
    ],
    "b": [
      0.04,
      0.3,
      0.75,
      0
    ],
    "c": [
      0,
      0.2,
      0.25,
      53
    ],
    "base": [
      1.7,
      0.8,
      1.5
    ]
  },
  {
    "name": "Crimson shard field",
    "deep": [
      0.16,
      0,
      0.02
    ],
    "bright": [
      1,
      0.35,
      0.3
    ],
    "a": [
      9,
      2.1,
      1.7,
      0.6
    ],
    "b": [
      0.2,
      0.8,
      0.3,
      0
    ],
    "c": [
      0,
      0.1,
      0.1,
      67
    ],
    "base": [
      3.9,
      0.55,
      3.4
    ]
  },
  {
    "name": "Sapphire geode",
    "deep": [
      0.01,
      0.03,
      0.16
    ],
    "bright": [
      0.3,
      0.5,
      1
    ],
    "special": 1,
    "g": [
      3,
      2,
      1.7
    ],
    "view": [
      [
        0,
        1.8,
        0
      ],
      17
    ],
    "glow": [
      0,
      1.7,
      -1.2
    ]
  },
  {
    "name": "Magenta floating heart",
    "deep": [
      0.14,
      0,
      0.12
    ],
    "bright": [
      1,
      0.4,
      0.85
    ],
    "special": 2,
    "g": [
      1,
      0.8,
      0
    ],
    "view": [
      [
        0,
        2.8,
        0
      ],
      17
    ],
    "glow": [
      0,
      3.4,
      -1.6
    ]
  },
  {
    "name": "Jade crystal tree",
    "deep": [
      0,
      0.1,
      0.07
    ],
    "bright": [
      0.35,
      0.95,
      0.75
    ],
    "special": 3,
    "g": [
      0,
      6,
      0
    ],
    "view": [
      [
        0,
        3.2,
        0
      ],
      19
    ],
    "glow": [
      0,
      3.5,
      -2
    ]
  },
  {
    "name": "Gold spiral",
    "deep": [
      0.16,
      0.11,
      0
    ],
    "bright": [
      1,
      0.9,
      0.4
    ],
    "special": 4,
    "g": [
      0,
      5.8,
      0
    ],
    "view": [
      [
        0,
        3,
        0
      ],
      18
    ],
    "glow": [
      0,
      3,
      -2.2
    ]
  },
  {
    "name": "Molten split boulder",
    "deep": [
      0.18,
      0.04,
      0
    ],
    "bright": [
      1,
      0.48,
      0.12
    ],
    "special": 5,
    "g": [
      0,
      5,
      0
    ],
    "view": [
      [
        0,
        2.6,
        0
      ],
      19
    ],
    "glow": [
      0,
      3,
      -2.5
    ]
  },
  {
    "name": "Pearl hanging cluster",
    "deep": [
      0.14,
      0.09,
      0.12
    ],
    "bright": [
      1,
      0.82,
      0.9
    ],
    "special": 6,
    "g": [
      2,
      7.6,
      3.8
    ],
    "view": [
      [
        0,
        5.6,
        0
      ],
      19
    ],
    "glow": [
      0,
      5,
      -1.8
    ]
  },
  {
    "name": "Aurora urchin",
    "deep": [
      0,
      0.22,
      0.24
    ],
    "bright": [
      0.8,
      0.5,
      1
    ],
    "special": 7,
    "g": [
      4,
      2.4,
      0.5
    ],
    "view": [
      [
        0,
        1.6,
        0
      ],
      15
    ],
    "glow": [
      0,
      1.6,
      -2
    ]
  }
];
