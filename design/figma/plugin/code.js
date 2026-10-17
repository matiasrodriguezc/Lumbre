// Lumbre tokens: crea o actualiza las variables y estilos de Lumbre en este archivo de Figma.
// Generado por design/figma/generar_variables.py desde design/system/tokens.json. No editar a mano.
const DATA = {
 "colors": [
  {
   "name": "marca/neuron",
   "description": "Marca: negro neurona. El símbolo, la tinta del tema gris y el relleno del botón principal. Fijo en ambos temas.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL",
    "TEXT_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--neuron)",
   "ios": "Palette.neuron",
   "values": {
    "Gris": {
     "r": 0.054901960784313725,
     "g": 0.054901960784313725,
     "b": 0.06274509803921569,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.054901960784313725,
     "g": 0.054901960784313725,
     "b": 0.06274509803921569,
     "a": 1.0
    }
   }
  },
  {
   "name": "marca/gray",
   "description": "Marca: gris. Fondo del tema de marca (default) y del ícono de app. Fijo en ambos temas.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--gray)",
   "ios": "Palette.gray",
   "values": {
    "Gris": {
     "r": 0.8901960784313725,
     "g": 0.8901960784313725,
     "b": 0.8745098039215686,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.8901960784313725,
     "g": 0.8901960784313725,
     "b": 0.8745098039215686,
     "a": 1.0
    }
   }
  },
  {
   "name": "marca/graphite",
   "description": "Marca: grafito. Fondo del modo oscuro. Fijo en ambos temas.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--graphite)",
   "ios": "Palette.graphite",
   "values": {
    "Gris": {
     "r": 0.16470588235294117,
     "g": 0.16470588235294117,
     "b": 0.17254901960784313,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.16470588235294117,
     "g": 0.16470588235294117,
     "b": 0.17254901960784313,
     "a": 1.0
    }
   }
  },
  {
   "name": "marca/bone",
   "description": "Marca: hueso. La neurona y la tinta en el modo oscuro. Fijo en ambos temas.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL",
    "TEXT_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--bone)",
   "ios": "Palette.bone",
   "values": {
    "Gris": {
     "r": 0.9294117647058824,
     "g": 0.9294117647058824,
     "b": 0.9098039215686274,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.9294117647058824,
     "g": 0.9294117647058824,
     "b": 0.9098039215686274,
     "a": 1.0
    }
   }
  },
  {
   "name": "marca/spark",
   "description": "Marca: rosa chispa. El único color. Siempre apoyado en negro (o en la neurona): el núcleo, el punto del botón principal, la chispa en la sinapsis. Sobre gris no alcanza contraste (2,5:1): nunca como texto ni relleno grande sobre bg.",
   "scopes": [
    "SHAPE_FILL",
    "EFFECT_COLOR"
   ],
   "web": "var(--spark)",
   "ios": "Palette.spark",
   "values": {
    "Gris": {
     "r": 1.0,
     "g": 0.24313725490196078,
     "b": 0.6470588235294118,
     "a": 1.0
    },
    "Grafito": {
     "r": 1.0,
     "g": 0.24313725490196078,
     "b": 0.6470588235294118,
     "a": 1.0
    }
   }
  },
  {
   "name": "superficie/bg",
   "description": "Fondo de pantalla (window/scaffold).",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--bg)",
   "ios": "Palette.bg",
   "values": {
    "Gris": {
     "r": 0.8901960784313725,
     "g": 0.8901960784313725,
     "b": 0.8745098039215686,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.16470588235294117,
     "g": 0.16470588235294117,
     "b": 0.17254901960784313,
     "a": 1.0
    }
   }
  },
  {
   "name": "superficie/surface",
   "description": "Superficies apenas elevadas: sheets, barras y la tarjeta de neurona.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--surface)",
   "ios": "Palette.surface",
   "values": {
    "Gris": {
     "r": 0.9254901960784314,
     "g": 0.9254901960784314,
     "b": 0.9137254901960784,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.19607843137254902,
     "g": 0.19607843137254902,
     "b": 0.20784313725490197,
     "a": 1.0
    }
   }
  },
  {
   "name": "superficie/surface-alt",
   "description": "Inputs, campos de búsqueda, chips inactivos y neuronas dormidas de las ilustraciones.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--surface-alt)",
   "ios": "Palette.surfaceAlt",
   "values": {
    "Gris": {
     "r": 0.8352941176470589,
     "g": 0.8352941176470589,
     "b": 0.8156862745098039,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.23137254901960785,
     "g": 0.23137254901960785,
     "b": 0.24313725490196078,
     "a": 1.0
    }
   }
  },
  {
   "name": "texto/ink",
   "description": "Texto principal, íconos y neuronas encendidas (≥9:1 en ambos temas).",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--ink)",
   "ios": "Palette.ink",
   "values": {
    "Gris": {
     "r": 0.054901960784313725,
     "g": 0.054901960784313725,
     "b": 0.06274509803921569,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.9294117647058824,
     "g": 0.9294117647058824,
     "b": 0.9098039215686274,
     "a": 1.0
    }
   }
  },
  {
   "name": "texto/ink-muted",
   "description": "Texto secundario y metadatos (≥4.4:1 en todas las superficies).",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--ink-muted)",
   "ios": "Palette.inkMuted",
   "values": {
    "Gris": {
     "r": 0.35294117647058826,
     "g": 0.35294117647058826,
     "b": 0.3686274509803922,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.6392156862745098,
     "g": 0.6392156862745098,
     "b": 0.6509803921568628,
     "a": 1.0
    }
   }
  },
  {
   "name": "borde/border",
   "description": "Separadores, el eje de las listas y las conexiones de la red de fondo. Decorativo.",
   "scopes": [
    "STROKE_COLOR",
    "SHAPE_FILL"
   ],
   "web": "var(--border)",
   "ios": "Palette.border",
   "values": {
    "Gris": {
     "r": 0.7764705882352941,
     "g": 0.7764705882352941,
     "b": 0.7529411764705882,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.27450980392156865,
     "g": 0.27450980392156865,
     "b": 0.2901960784313726,
     "a": 1.0
    }
   }
  },
  {
   "name": "borde/border-strong",
   "description": "Borde de controles (≥3:1).",
   "scopes": [
    "STROKE_COLOR",
    "SHAPE_FILL"
   ],
   "web": "var(--border-strong)",
   "ios": "Palette.borderStrong",
   "values": {
    "Gris": {
     "r": 0.4627450980392157,
     "g": 0.4627450980392157,
     "b": 0.47843137254901963,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.5490196078431373,
     "g": 0.5490196078431373,
     "b": 0.5647058823529412,
     "a": 1.0
    }
   }
  },
  {
   "name": "accion/accent",
   "description": "Relleno de la acción principal: negro en el tema gris, hueso en el grafito. Lleva el punto spark adentro.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--accent)",
   "ios": "Palette.accent",
   "alias": "texto/ink"
  },
  {
   "name": "accion/on-accent",
   "description": "Texto e íconos sobre accent.",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--on-accent)",
   "ios": "Palette.onAccent",
   "values": {
    "Gris": {
     "r": 0.9490196078431372,
     "g": 0.9490196078431372,
     "b": 0.9372549019607843,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.0784313725490196,
     "g": 0.0784313725490196,
     "b": 0.08627450980392157,
     "a": 1.0
    }
   }
  },
  {
   "name": "texto/accent-text",
   "description": "Rosa como texto chico cuando hace falta (links de la chispa). 5.3:1 sobre bg.",
   "scopes": [
    "TEXT_FILL"
   ],
   "web": "var(--accent-text)",
   "ios": "Palette.accentText",
   "values": {
    "Gris": {
     "r": 0.6901960784313725,
     "g": 0.06274509803921569,
     "b": 0.3686274509803922,
     "a": 1.0
    },
    "Grafito": {
     "r": 1.0,
     "g": 0.4196078431372549,
     "b": 0.7215686274509804,
     "a": 1.0
    }
   }
  },
  {
   "name": "accion/accent-soft",
   "description": "Fondo de selección. El elegido de verdad va en accent (negro) con on-accent.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--accent-soft)",
   "ios": "Palette.accentSoft",
   "values": {
    "Gris": {
     "r": 0.8156862745098039,
     "g": 0.8156862745098039,
     "b": 0.796078431372549,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.27450980392156865,
     "g": 0.27450980392156865,
     "b": 0.2901960784313726,
     "a": 1.0
    }
   }
  },
  {
   "name": "accion/pro",
   "description": "Pro: negro con la palabra Pro. Ya no hay un color propio.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--pro)",
   "ios": "Palette.pro",
   "alias": "texto/ink"
  },
  {
   "name": "accion/on-pro",
   "description": "Texto sobre pro.",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--on-pro)",
   "ios": "Palette.onPro",
   "values": {
    "Gris": {
     "r": 0.9490196078431372,
     "g": 0.9490196078431372,
     "b": 0.9372549019607843,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.0784313725490196,
     "g": 0.0784313725490196,
     "b": 0.08627450980392157,
     "a": 1.0
    }
   }
  },
  {
   "name": "texto/pro-text",
   "description": "Texto de cosas Pro: siempre junto a la palabra Pro o un ícono.",
   "scopes": [
    "TEXT_FILL"
   ],
   "web": "var(--pro-text)",
   "ios": "Palette.proText",
   "values": {
    "Gris": {
     "r": 0.054901960784313725,
     "g": 0.054901960784313725,
     "b": 0.06274509803921569,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.9294117647058824,
     "g": 0.9294117647058824,
     "b": 0.9098039215686274,
     "a": 1.0
    }
   }
  },
  {
   "name": "texto/info-text",
   "description": "Información neutra y links secundarios (subrayados).",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--info-text)",
   "ios": "Palette.infoText",
   "values": {
    "Gris": {
     "r": 0.22745098039215686,
     "g": 0.22745098039215686,
     "b": 0.24313725490196078,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.7843137254901961,
     "g": 0.7843137254901961,
     "b": 0.796078431372549,
     "a": 1.0
    }
   }
  },
  {
   "name": "estado/success",
   "description": "Éxito, siempre con ícono y palabra.",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--success)",
   "ios": "Palette.success",
   "values": {
    "Gris": {
     "r": 0.050980392156862744,
     "g": 0.3803921568627451,
     "b": 0.27058823529411763,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.30980392156862746,
     "g": 0.8196078431372549,
     "b": 0.6470588235294118,
     "a": 1.0
    }
   }
  },
  {
   "name": "estado/warning",
   "description": "Advertencia, siempre con ícono y palabra.",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--warning)",
   "ios": "Palette.warning",
   "values": {
    "Gris": {
     "r": 0.47843137254901963,
     "g": 0.30980392156862746,
     "b": 0.0,
     "a": 1.0
    },
    "Grafito": {
     "r": 1.0,
     "g": 0.7607843137254902,
     "b": 0.29411764705882354,
     "a": 1.0
    }
   }
  },
  {
   "name": "estado/danger",
   "description": "Error y acciones destructivas, siempre con ícono y palabra.",
   "scopes": [
    "TEXT_FILL",
    "SHAPE_FILL",
    "STROKE_COLOR"
   ],
   "web": "var(--danger)",
   "ios": "Palette.danger",
   "values": {
    "Gris": {
     "r": 0.6392156862745098,
     "g": 0.13333333333333333,
     "b": 0.10588235294117647,
     "a": 1.0
    },
    "Grafito": {
     "r": 1.0,
     "g": 0.47843137254901963,
     "b": 0.4196078431372549,
     "a": 1.0
    }
   }
  },
  {
   "name": "borde/focus-ring",
   "description": "Anillo de foco de 2px, separado 2px del control.",
   "scopes": [
    "STROKE_COLOR"
   ],
   "web": "var(--focus-ring)",
   "ios": "Palette.focusRing",
   "values": {
    "Gris": {
     "r": 0.054901960784313725,
     "g": 0.054901960784313725,
     "b": 0.06274509803921569,
     "a": 1.0
    },
    "Grafito": {
     "r": 0.9294117647058824,
     "g": 0.9294117647058824,
     "b": 0.9098039215686274,
     "a": 1.0
    }
   }
  },
  {
   "name": "superficie/scrim",
   "description": "Velo detrás de sheets y diálogos.",
   "scopes": [
    "FRAME_FILL",
    "SHAPE_FILL"
   ],
   "web": "var(--scrim)",
   "ios": "Palette.scrim",
   "values": {
    "Gris": {
     "r": 0.054901960784313725,
     "g": 0.054901960784313725,
     "b": 0.06274509803921569,
     "a": 0.5
    },
    "Grafito": {
     "r": 0.054901960784313725,
     "g": 0.054901960784313725,
     "b": 0.06274509803921569,
     "a": 0.5
    }
   }
  }
 ],
 "floats": [
  {
   "name": "espacio/space-1",
   "value": 4.0,
   "description": "Separación ícono–texto dentro de un chip.",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-1)",
   "ios": "Space.s1"
  },
  {
   "name": "espacio/space-2",
   "value": 8.0,
   "description": "Gap entre chips y entre líneas de metadatos.",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-2)",
   "ios": "Space.s2"
  },
  {
   "name": "espacio/space-3",
   "value": 12.0,
   "description": "Padding vertical de botones y filas compactas.",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-3)",
   "ios": "Space.s3"
  },
  {
   "name": "espacio/space-4",
   "value": 16.0,
   "description": "Padding de tarjetas y márgenes laterales de pantalla.",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-4)",
   "ios": "Space.s4"
  },
  {
   "name": "espacio/space-5",
   "value": 20.0,
   "description": "Margen lateral en pantallas de lectura (Android usa 16 o 24 según ancho).",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-5)",
   "ios": "Space.s5"
  },
  {
   "name": "espacio/space-6",
   "value": 24.0,
   "description": "Separación entre secciones de una pantalla.",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-6)",
   "ios": "Space.s6"
  },
  {
   "name": "espacio/space-8",
   "value": 32.0,
   "description": "Aire alrededor de la chispa revelada.",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-8)",
   "ios": "Space.s8"
  },
  {
   "name": "espacio/space-10",
   "value": 40.0,
   "description": "Separación de bloques en onboarding y paywall.",
   "scopes": [
    "GAP",
    "WIDTH_HEIGHT"
   ],
   "web": "var(--space-10)",
   "ios": "Space.s10"
  },
  {
   "name": "radio/radius-sm",
   "value": 8.0,
   "description": "Inputs, chips cuadrados, thumbnails.",
   "scopes": [
    "CORNER_RADIUS"
   ],
   "web": "var(--radius-sm)",
   "ios": "Radius.sm"
  },
  {
   "name": "radio/radius-md",
   "value": 14.0,
   "description": "Tarjetas de concepto, botones, filas agrupadas.",
   "scopes": [
    "CORNER_RADIUS"
   ],
   "web": "var(--radius-md)",
   "ios": "Radius.md"
  },
  {
   "name": "radio/radius-lg",
   "value": 24.0,
   "description": "La tarjeta de la chispa del día y los sheets.",
   "scopes": [
    "CORNER_RADIUS"
   ],
   "web": "var(--radius-lg)",
   "ios": "Radius.lg"
  },
  {
   "name": "radio/radius-full",
   "value": 999.0,
   "description": "Pills: chips de dominio, badge Pro, contador.",
   "scopes": [
    "CORNER_RADIUS"
   ],
   "web": "var(--radius-full)",
   "ios": "Radius.full"
  }
 ],
 "typeVars": [
  {
   "name": "familia/display",
   "type": "STRING",
   "values": {
    "iOS": "Fraunces",
    "Android": "Fraunces"
   },
   "scopes": [
    "FONT_FAMILY"
   ],
   "description": "Fraunces solo para marca y títulos de 20 pt o más."
  },
  {
   "name": "familia/text",
   "type": "STRING",
   "values": {
    "iOS": "SF Pro Text",
    "Android": "Roboto Flex"
   },
   "scopes": [
    "FONT_FAMILY"
   ],
   "description": "Fuente del sistema para todo lo demás."
  },
  {
   "name": "texto/spark-hero/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 34.0,
    "Android": 34.0
   },
   "description": "Título de la chispa revelada. Uno por pantalla. Fraunces con SOFT 100."
  },
  {
   "name": "texto/spark-hero/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 38.0,
    "Android": 38.0
   },
   "description": "Título de la chispa revelada. Uno por pantalla. Fraunces con SOFT 100."
  },
  {
   "name": "texto/counter/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 44.0,
    "Android": 44.0
   },
   "description": "Contador de chispas y números grandes. Siempre con cifras de caja alta y tabulares (lining-nums tabular-nums)."
  },
  {
   "name": "texto/counter/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 44.0,
    "Android": 44.0
   },
   "description": "Contador de chispas y números grandes. Siempre con cifras de caja alta y tabulares (lining-nums tabular-nums)."
  },
  {
   "name": "texto/title-1/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 28.0,
    "Android": 28.0
   },
   "description": "Título grande de pantalla (iOS large title / M3 headlineMedium). Nunca por debajo de 20pt."
  },
  {
   "name": "texto/title-1/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 34.0,
    "Android": 34.0
   },
   "description": "Título grande de pantalla (iOS large title / M3 headlineMedium). Nunca por debajo de 20pt."
  },
  {
   "name": "texto/title-2/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 22.0,
    "Android": 22.0
   },
   "description": "Títulos de sección, onboarding y paywall. Tamaño mínimo para Fraunces en toda la app."
  },
  {
   "name": "texto/title-2/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 28.0,
    "Android": 28.0
   },
   "description": "Títulos de sección, onboarding y paywall. Tamaño mínimo para Fraunces en toda la app."
  },
  {
   "name": "texto/headline/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 17.0,
    "Android": 17.0
   },
   "description": "Título de tarjeta de concepto y filas de lista."
  },
  {
   "name": "texto/headline/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 22.0,
    "Android": 22.0
   },
   "description": "Título de tarjeta de concepto y filas de lista."
  },
  {
   "name": "texto/body/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 17.0,
    "Android": 16.0
   },
   "description": "Texto corrido y chat. En Android se mapea a bodyLarge (16sp)."
  },
  {
   "name": "texto/body/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 24.0,
    "Android": 24.0
   },
   "description": "Texto corrido y chat. En Android se mapea a bodyLarge (16sp)."
  },
  {
   "name": "texto/callout/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 15.0,
    "Android": 15.0
   },
   "description": "Tesis del concepto, descripciones secundarias."
  },
  {
   "name": "texto/callout/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 20.0,
    "Android": 20.0
   },
   "description": "Tesis del concepto, descripciones secundarias."
  },
  {
   "name": "texto/caption/tamano",
   "type": "FLOAT",
   "scopes": [
    "FONT_SIZE"
   ],
   "values": {
    "iOS": 13.0,
    "Android": 13.0
   },
   "description": "Metadatos, fuente, timestamps, etiquetas de tab."
  },
  {
   "name": "texto/caption/interlineado",
   "type": "FLOAT",
   "scopes": [
    "LINE_HEIGHT"
   ],
   "values": {
    "iOS": 18.0,
    "Android": 18.0
   },
   "description": "Metadatos, fuente, timestamps, etiquetas de tab."
  }
 ],
 "textStyles": [
  {
   "name": "iOS/spark-hero",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 34.0,
   "lineHeight": 38.0,
   "letterSpacing": -1.0,
   "description": "Título de la chispa revelada. Uno por pantalla. Fraunces con SOFT 100. Muestra: Podcast × ruinas",
   "tabular": false
  },
  {
   "name": "Android/spark-hero",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 34.0,
   "lineHeight": 38.0,
   "letterSpacing": -1.0,
   "description": "Título de la chispa revelada. Uno por pantalla. Fraunces con SOFT 100. Muestra: Podcast × ruinas",
   "tabular": false
  },
  {
   "name": "iOS/counter",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 44.0,
   "lineHeight": 44.0,
   "letterSpacing": -1.0,
   "description": "Contador de chispas y números grandes. Siempre con cifras de caja alta y tabulares (lining-nums tabular-nums). Muestra: 1/1",
   "tabular": true
  },
  {
   "name": "Android/counter",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 44.0,
   "lineHeight": 44.0,
   "letterSpacing": -1.0,
   "description": "Contador de chispas y números grandes. Siempre con cifras de caja alta y tabulares (lining-nums tabular-nums). Muestra: 1/1",
   "tabular": true
  },
  {
   "name": "iOS/title-1",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 28.0,
   "lineHeight": 34.0,
   "letterSpacing": -1.0,
   "description": "Título grande de pantalla (iOS large title / M3 headlineMedium). Nunca por debajo de 20pt. Muestra: Tu red",
   "tabular": false
  },
  {
   "name": "Android/title-1",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 28.0,
   "lineHeight": 34.0,
   "letterSpacing": -1.0,
   "description": "Título grande de pantalla (iOS large title / M3 headlineMedium). Nunca por debajo de 20pt. Muestra: Tu red",
   "tabular": false
  },
  {
   "name": "iOS/title-2",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 22.0,
   "lineHeight": 28.0,
   "letterSpacing": -1.0,
   "description": "Títulos de sección, onboarding y paywall. Tamaño mínimo para Fraunces en toda la app. Muestra: Elegí tu perfil",
   "tabular": false
  },
  {
   "name": "Android/title-2",
   "family": "Fraunces",
   "style": "SemiBold",
   "size": 22.0,
   "lineHeight": 28.0,
   "letterSpacing": -1.0,
   "description": "Títulos de sección, onboarding y paywall. Tamaño mínimo para Fraunces en toda la app. Muestra: Elegí tu perfil",
   "tabular": false
  },
  {
   "name": "iOS/headline",
   "family": "SF Pro Text",
   "style": "Semibold",
   "size": 17.0,
   "lineHeight": 22.0,
   "letterSpacing": 0.0,
   "description": "Título de tarjeta de concepto y filas de lista. Muestra: Indexación vectorial",
   "tabular": false
  },
  {
   "name": "Android/headline",
   "family": "Roboto Flex",
   "style": "SemiBold",
   "size": 17.0,
   "lineHeight": 22.0,
   "letterSpacing": 0.0,
   "description": "Título de tarjeta de concepto y filas de lista. Muestra: Indexación vectorial",
   "tabular": false
  },
  {
   "name": "iOS/body",
   "family": "SF Pro Text",
   "style": "Regular",
   "size": 17.0,
   "lineHeight": 24.0,
   "letterSpacing": 0.0,
   "description": "Texto corrido y chat. En Android se mapea a bodyLarge (16sp). Muestra: Aplicá la lógica de los ciclones industriales a una aspiradora.",
   "tabular": false
  },
  {
   "name": "Android/body",
   "family": "Roboto Flex",
   "style": "Regular",
   "size": 16.0,
   "lineHeight": 24.0,
   "letterSpacing": 0.0,
   "description": "Texto corrido y chat. En Android se mapea a bodyLarge (16sp). Muestra: Aplicá la lógica de los ciclones industriales a una aspiradora.",
   "tabular": false
  },
  {
   "name": "iOS/callout",
   "family": "SF Pro Text",
   "style": "Regular",
   "size": 15.0,
   "lineHeight": 20.0,
   "letterSpacing": 0.0,
   "description": "Tesis del concepto, descripciones secundarias. Muestra: La tesis en una frase.",
   "tabular": false
  },
  {
   "name": "Android/callout",
   "family": "Roboto Flex",
   "style": "Regular",
   "size": 15.0,
   "lineHeight": 20.0,
   "letterSpacing": 0.0,
   "description": "Tesis del concepto, descripciones secundarias. Muestra: La tesis en una frase.",
   "tabular": false
  },
  {
   "name": "iOS/caption",
   "family": "SF Pro Text",
   "style": "Medium",
   "size": 13.0,
   "lineHeight": 18.0,
   "letterSpacing": 0.0,
   "description": "Metadatos, fuente, timestamps, etiquetas de tab. Muestra: Guardado desde un artículo",
   "tabular": false
  },
  {
   "name": "Android/caption",
   "family": "Roboto Flex",
   "style": "Medium",
   "size": 13.0,
   "lineHeight": 18.0,
   "letterSpacing": 0.0,
   "description": "Metadatos, fuente, timestamps, etiquetas de tab. Muestra: Guardado desde un artículo",
   "tabular": false
  }
 ],
 "effects": [
  {
   "name": "glow-spark/Gris",
   "shadows": [
    {
     "x": 0.0,
     "y": 8.0,
     "blur": 24.0,
     "color": {
      "r": 0.054901960784313725,
      "g": 0.054901960784313725,
      "b": 0.06274509803921569,
      "a": 0.16
     }
    }
   ],
   "description": "Solo la chispa revelada y el botón principal en su primer segundo. Nunca en tarjetas comunes."
  },
  {
   "name": "glow-spark/Grafito",
   "shadows": [
    {
     "x": 0.0,
     "y": 0.0,
     "blur": 28.0,
     "color": {
      "r": 1.0,
      "g": 0.24313725490196078,
      "b": 0.6470588235294118,
      "a": 0.3
     }
    }
   ],
   "description": "Solo la chispa revelada y el botón principal en su primer segundo. Nunca en tarjetas comunes."
  },
  {
   "name": "elev-card/Gris",
   "shadows": [
    {
     "x": 0.0,
     "y": 1.0,
     "blur": 2.0,
     "color": {
      "r": 0.054901960784313725,
      "g": 0.054901960784313725,
      "b": 0.06274509803921569,
      "a": 0.06
     }
    },
    {
     "x": 0.0,
     "y": 4.0,
     "blur": 16.0,
     "color": {
      "r": 0.054901960784313725,
      "g": 0.054901960784313725,
      "b": 0.06274509803921569,
      "a": 0.06
     }
    }
   ],
   "description": "Tarjetas en modo claro. En oscuro la elevación se da con surface/surface-alt, no con sombra."
  }
 ]
};

const THEME_MODES = ["Gris", "Grafito"];
const PLATFORM_MODES = ["iOS", "Android"];
const report = { created: 0, updated: 0, textStyles: 0, effectStyles: 0, missingFonts: [] };

async function collection(name, modes) {
  const all = await figma.variables.getLocalVariableCollectionsAsync();
  let c = all.find((x) => x.name === name);
  if (!c) c = figma.variables.createVariableCollection(name);
  const ids = {};
  modes.forEach((mode, i) => {
    let m = c.modes.find((x) => x.name === mode);
    if (!m && i === 0) { c.renameMode(c.modes[0].modeId, mode); m = c.modes[0]; }
    if (!m) { const id = c.addMode(mode); m = { modeId: id, name: mode }; }
    ids[mode] = m.modeId;
  });
  return { c, ids };
}

async function variable(name, coll, type) {
  const all = await figma.variables.getLocalVariablesAsync(type);
  let v = all.find((x) => x.name === name && x.variableCollectionId === coll.id);
  if (v) { report.updated++; return v; }
  report.created++;
  return figma.variables.createVariable(name, coll, type);
}

function codeSyntax(v, item) {
  if (item.web) v.setVariableCodeSyntax("WEB", item.web);
  if (item.ios) v.setVariableCodeSyntax("iOS", item.ios);
}

// Si falta la fuente, prueba la familia hermana y después Inter (y lo avisa al cerrar).
const ALTERNATES = { "SF Pro Text": ["SF Pro"], "Roboto Flex": ["Roboto"], "Fraunces": [] };
async function loadFont(family, style) {
  const styles = (s) => [s, s.replace("SemiBold", "Semibold"), s.replace("Semibold", "SemiBold"), s.replace(/Semi ?[Bb]old/, "Semi Bold")];
  for (const fam of [family, ...(ALTERNATES[family] || [])]) {
    for (const st of [...new Set(styles(style))]) {
      try { await figma.loadFontAsync({ family: fam, style: st }); if (fam !== family) report.missingFonts.push(family + " (se usó " + fam + ")"); return { family: fam, style: st }; }
      catch (e) { /* sigue probando */ }
    }
  }
  report.missingFonts.push(family + " " + style + " (se usó Inter)");
  for (const st of [...new Set(styles(style))]) {
    try { await figma.loadFontAsync({ family: "Inter", style: st }); return { family: "Inter", style: st }; } catch (e) { /* sigue */ }
  }
  await figma.loadFontAsync({ family: "Inter", style: "Regular" });
  return { family: "Inter", style: "Regular" };
}

async function run() {
  // Color: modos Gris (default) y Grafito.
  const color = await collection("Color", THEME_MODES);
  const byName = {};
  for (const item of DATA.colors.filter((x) => !x.alias)) {
    const v = await variable(item.name, color.c, "COLOR");
    for (const mode of THEME_MODES) v.setValueForMode(color.ids[mode], item.values[mode]);
    v.description = item.description; v.scopes = item.scopes; codeSyntax(v, item);
    byName[item.name] = v;
  }
  for (const item of DATA.colors.filter((x) => x.alias)) {
    const v = await variable(item.name, color.c, "COLOR");
    const target = byName[item.alias];
    for (const mode of THEME_MODES) v.setValueForMode(color.ids[mode], figma.variables.createVariableAlias(target));
    v.description = item.description; v.scopes = item.scopes; codeSyntax(v, item);
  }

  // Espaciado y radios: un solo modo.
  const space = await collection("Espaciado", ["Valor"]);
  for (const item of DATA.floats) {
    const v = await variable(item.name, space.c, "FLOAT");
    v.setValueForMode(space.ids["Valor"], item.value);
    v.description = item.description; v.scopes = item.scopes; codeSyntax(v, item);
  }

  // Tipografía: modos iOS y Android.
  const type = await collection("Tipografía", PLATFORM_MODES);
  for (const item of DATA.typeVars) {
    const v = await variable(item.name, type.c, item.type);
    for (const mode of PLATFORM_MODES) v.setValueForMode(type.ids[mode], item.values[mode]);
    v.description = item.description; v.scopes = item.scopes;
  }

  // Estilos de texto, uno por plataforma (iOS/… y Android/…).
  const textStyles = await figma.getLocalTextStylesAsync();
  for (const s of DATA.textStyles) {
    const font = await loadFont(s.family, s.style);
    let st = textStyles.find((x) => x.name === s.name);
    if (!st) { st = figma.createTextStyle(); st.name = s.name; }
    st.fontName = font;
    st.fontSize = s.size;
    st.lineHeight = { unit: "PIXELS", value: s.lineHeight };
    st.letterSpacing = { unit: "PERCENT", value: s.letterSpacing };
    st.description = s.description;
    report.textStyles++;
  }

  // Estilos de efecto: glow-spark y elev-card por tema.
  const effectStyles = await figma.getLocalEffectStylesAsync();
  for (const e of DATA.effects) {
    let st = effectStyles.find((x) => x.name === e.name);
    if (!st) { st = figma.createEffectStyle(); st.name = e.name; }
    st.effects = e.shadows.map((s) => ({
      type: "DROP_SHADOW", color: s.color, offset: { x: s.x, y: s.y }, radius: s.blur, spread: 0,
      visible: true, blendMode: "NORMAL", showShadowBehindNode: false,
    }));
    st.description = e.description;
    report.effectStyles++;
  }
}

run().then(() => {
  const fonts = report.missingFonts.length ? ` Fuentes faltantes: ${[...new Set(report.missingFonts)].join(", ")}.` : "";
  figma.closePlugin(`Lumbre: ${report.created} variables nuevas, ${report.updated} actualizadas, ${report.textStyles} estilos de texto y ${report.effectStyles} de efecto.${fonts}`);
}).catch((e) => figma.closePlugin("Lumbre: no se pudo importar. " + (e && e.message ? e.message : e)));
