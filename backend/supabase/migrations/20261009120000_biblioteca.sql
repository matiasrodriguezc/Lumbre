-- Biblioteca de conceptos invitados (paso 31, plan.md §5).
--
-- - Es el respaldo del emparejamiento: si el usuario todavía no tiene un par posible, se combina un concepto suyo
--   con uno de acá, de otro dominio, para que Hoy nunca quede vacía.
-- - Se elige entre los conceptos de sus perfiles creativos (o de todos si no eligió ninguno). El elegido se copia
--   a la bóveda del usuario con from_library = true.
-- - Cada perfil tiene conceptos de mundos variados, no solo del suyo: lo que sirve es el cruce.
-- - El embedding lo completa /process (mismo modelo que los conceptos del usuario).

create table public.library_concepts (
  id uuid primary key default gen_random_uuid(),
  -- Mismos slugs que profiles.creative_profiles.
  profile text not null check (profile in ('software', 'content', 'business', 'design', 'curiosity')),
  domain text not null references public.domains (slug),
  title text not null check (char_length(title) between 1 and 120),
  thesis text not null check (char_length(thesis) between 1 and 600),
  principle text not null,
  locale text not null default 'es' check (locale in ('es', 'en')),
  embedding extensions.vector(1024),
  embedding_model text,
  created_at timestamptz not null default now(),
  unique (profile, title),
  check ((embedding is null) = (embedding_model is null))
);

create index library_concepts_domain_idx on public.library_concepts (domain);

comment on table public.library_concepts is 'Conceptos curados por perfil creativo. Respaldo del emparejamiento; se copian a la bóveda con from_library = true.';

alter table public.library_concepts enable row level security;
create policy "library_concepts: lectura" on public.library_concepts
  for select to authenticated using (true);
revoke all on public.library_concepts from anon;
revoke insert, update, delete on public.library_concepts from authenticated;

-- De qué concepto de la biblioteca salió la copia (para no copiar dos veces el mismo).
alter table public.concepts
  add column library_id uuid references public.library_concepts (id) on delete set null;
create index concepts_library_idx on public.concepts (library_id) where library_id is not null;

insert into public.library_concepts (profile, domain, title, thesis, principle) values
  -- Software y apps
  ('software', 'biologia', 'Hormigas y feromonas',
   'Las hormigas encuentran el camino más corto reforzando con feromona los senderos que más se usan.',
   'Un sistema sin jefe optimiza si el uso deja rastro y el rastro se evapora.'),
  ('software', 'arquitectura', 'Senderos de deseo',
   'Los caminos que la gente marca en el pasto muestran por dónde quiere ir, no por dónde se planeó.',
   'El uso real dibuja el diseño correcto antes que el plano.'),
  ('software', 'cocina', 'Mise en place',
   'En una cocina profesional todo se corta y se ordena antes de encender el fuego.',
   'Preparar el entorno antes de ejecutar convierte la presión en rutina.'),
  ('software', 'salud', 'Triage',
   'En una guardia se atiende primero al más grave, no al que llegó antes.',
   'Ordenar por urgencia y no por llegada salva lo que importa cuando falta capacidad.'),
  ('software', 'ingenieria', 'Fusible',
   'Un fusible se quema a propósito para que no se queme la casa.',
   'Una falla chica y controlada protege al sistema de una falla grande.'),
  ('software', 'musica', 'Ensayo general',
   'Antes del estreno se toca la obra completa, con vestuario y luces, como si hubiera público.',
   'Probar todo junto en condiciones reales revela lo que las partes sueltas esconden.'),
  ('software', 'historia', 'Rutas de la seda',
   'El comercio entre Oriente y Occidente pasaba por muchas manos: nadie hacía el recorrido completo.',
   'Una cadena de intermediarios locales mueve más lejos que un solo viajero.'),
  ('software', 'deporte', 'Relevo 4x100',
   'En la posta, la carrera se gana o se pierde en la zona donde se pasa el testigo.',
   'En un proceso en cadena, los traspasos pesan más que la velocidad de cada tramo.'),
  ('software', 'juegos', 'Niebla de guerra',
   'En los juegos de estrategia solo se ve lo que tus unidades tienen cerca.',
   'Decidir con información parcial obliga a explorar antes de comprometerse.'),

  -- Contenido y escritura
  ('content', 'biologia', 'Floración sincronizada',
   'Algunos bambúes florecen todos juntos cada décadas y saturan a los depredadores de semillas.',
   'Aparecer todos a la vez abruma la capacidad de consumo y asegura que algo sobreviva.'),
  ('content', 'fisica', 'Resonancia',
   'Un puente puede oscilar hasta romperse si recibe empujones chicos al ritmo justo.',
   'Pequeños impulsos repetidos en el momento exacto acumulan un efecto enorme.'),
  ('content', 'cocina', 'Masa madre',
   'La masa madre se alimenta todos los días y una parte siempre se guarda para el pan siguiente.',
   'Lo que se cultiva con constancia y se comparte de a poco nunca se agota.'),
  ('content', 'historia', 'Folletines del siglo XIX',
   'Dickens publicaba sus novelas por entregas y los lectores esperaban en el puerto el capítulo siguiente.',
   'Cortar en el momento justo convierte la espera en parte del placer.'),
  ('content', 'psicologia', 'Efecto Zeigarnik',
   'Recordamos mejor las tareas interrumpidas que las terminadas.',
   'Lo inconcluso queda abierto en la mente y pide volver.'),
  ('content', 'arquitectura', 'Plaza de pueblo',
   'La plaza central junta a la gente porque todos los caminos pasan por ahí.',
   'Un lugar de paso obligado se vuelve lugar de encuentro.'),
  ('content', 'deporte', 'Entrenamiento por intervalos',
   'Alternar esfuerzos máximos con descansos cortos mejora más que correr siempre al mismo ritmo.',
   'Contrastar intensidad y pausa rinde más que un esfuerzo parejo.'),
  ('content', 'matematicas', 'Ley de potencias',
   'En muchos sistemas unos pocos elementos concentran casi todo: pocas palabras, pocas ciudades, pocos libros.',
   'El impacto se reparte de forma desigual: unos pocos aciertos explican la mayoría del resultado.'),

  -- Negocios
  ('business', 'biologia', 'Simbiosis del pez payaso',
   'El pez payaso vive protegido entre los tentáculos de la anémona y a cambio la limpia y la defiende.',
   'Dos actores que se cubren las debilidades crecen más que compitiendo.'),
  ('business', 'fisica', 'Inercia',
   'Un cuerpo en movimiento tiende a seguir moviéndose y uno quieto, a quedarse quieto.',
   'Arrancar cuesta más que sostener: el primer empujón es el más caro.'),
  ('business', 'cocina', 'Menú del día',
   'Un restaurante con un menú corto compra menos variedad, desperdicia menos y sirve más rápido.',
   'Restringir la oferta simplifica la operación y mejora la calidad.'),
  ('business', 'deporte', 'Rotación de plantel',
   'Los equipos que juegan muchas competencias rotan jugadores para llegar enteros al final.',
   'Repartir la carga sostiene el rendimiento en temporadas largas.'),
  ('business', 'historia', 'Gremios medievales',
   'Los gremios controlaban la calidad y formaban aprendices durante años antes de dejarlos trabajar solos.',
   'Un estándar compartido y una formación larga protegen la reputación de todos.'),
  ('business', 'ambiente', 'Economía circular',
   'En un ecosistema no hay basura: lo que descarta uno es alimento de otro.',
   'Diseñar para que el residuo de un proceso sea insumo de otro elimina el desperdicio.'),
  ('business', 'juegos', 'Ajedrez: desarrollar piezas',
   'En la apertura conviene sacar todas las piezas antes de atacar con una sola.',
   'Preparar las capacidades antes de buscar el resultado evita ataques que no se sostienen.'),
  ('business', 'musica', 'Banda de jazz',
   'En el jazz cada músico improvisa sobre una estructura que todos conocen.',
   'Una estructura clara y compartida permite libertad individual sin caos.'),

  -- Diseño
  ('design', 'biologia', 'Camuflaje del pulpo',
   'El pulpo cambia de color y textura en milisegundos para fundirse con el fondo.',
   'Adaptarse al contexto en tiempo real vuelve invisible lo que no tiene que llamar la atención.'),
  ('design', 'arquitectura', 'Umbral',
   'El zaguán prepara al visitante para pasar de la calle a la casa.',
   'Un espacio de transición hace que el cambio de contexto se sienta natural.'),
  ('design', 'musica', 'Silencio en la partitura',
   'Los silencios marcan el ritmo tanto como las notas.',
   'El vacío bien ubicado da forma a lo que lo rodea.'),
  ('design', 'cocina', 'Emplatado',
   'El mismo plato servido con orden y espacio se percibe más rico.',
   'La presentación cambia la experiencia de algo que no cambió.'),
  ('design', 'ingenieria', 'Poka-yoke',
   'En las fábricas de Toyota las piezas solo encajan de la forma correcta.',
   'Hacer imposible el error es mejor que explicar cómo evitarlo.'),
  ('design', 'psicologia', 'Ley de Hick',
   'El tiempo para decidir crece con la cantidad de opciones disponibles.',
   'Menos opciones a la vista aceleran la decisión.'),
  ('design', 'historia', 'Señalética del metro de Londres',
   'El mapa del metro de Londres ignora las distancias reales y muestra solo conexiones.',
   'Simplificar la realidad hasta lo que se necesita para decidir la vuelve usable.'),
  ('design', 'deporte', 'Memoria muscular',
   'Un gesto repetido miles de veces se hace sin pensar.',
   'La consistencia convierte una acción en un reflejo que no cansa.'),

  -- Curiosidad libre
  ('curiosity', 'fisica', 'Entropía',
   'Sin aporte de energía, todo tiende al desorden: un cuarto ordenado no se ordena solo.',
   'Mantener algo organizado requiere un esfuerzo continuo.'),
  ('curiosity', 'biologia', 'Murmuración de estorninos',
   'Miles de estorninos vuelan como una sola forma siguiendo a sus siete vecinos más cercanos.',
   'Reglas locales simples generan un comportamiento global complejo.'),
  ('curiosity', 'historia', 'La imprenta de Gutenberg',
   'Los tipos móviles abarataron los libros y en cincuenta años circulaban millones de ejemplares.',
   'Bajar el costo de copiar cambia quién puede participar.'),
  ('curiosity', 'filosofia', 'El barco de Teseo',
   'Si a un barco se le cambian todas las tablas de a una, no queda claro si sigue siendo el mismo.',
   'La identidad puede estar en la continuidad y no en las partes.'),
  ('curiosity', 'quimica', 'Catalizador',
   'Un catalizador acelera una reacción sin consumirse en ella.',
   'Un facilitador cambia la velocidad del proceso sin ser parte del resultado.'),
  ('curiosity', 'ambiente', 'Especie clave',
   'Al volver los lobos a Yellowstone cambiaron los ciervos, los árboles y hasta el curso de los ríos.',
   'Un solo elemento bien ubicado reordena todo el sistema.'),
  ('curiosity', 'matematicas', 'Paradoja del cumpleaños',
   'Con 23 personas en una sala, la probabilidad de que dos cumplan el mismo día ya supera el 50%.',
   'Las coincidencias crecen con los pares posibles, no con la cantidad de elementos.'),
  ('curiosity', 'cine', 'Efecto Kuleshov',
   'La misma cara inexpresiva parece triste, hambrienta o enamorada según la imagen que la precede.',
   'El significado de algo depende de lo que se pone al lado.');
