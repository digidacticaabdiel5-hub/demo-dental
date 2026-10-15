/* ============================================================
   CONFIGURACIÓN DEL SITIO — Demo de consultorio dental
   Todos los datos son ficticios. Para probar las citas por
   WhatsApp, cambia `whatsapp` por tu propio número (52 + 10 dígitos).
   ============================================================ */
window.SITE = {
  name: "Clínica Dental Demo",
  sector: "Consultorio dental",
  description: "Sitio de demostración de un consultorio dental: servicios, equipo, horarios y reserva de citas. Datos ficticios.",
  schemaType: "Dentist",

  colors: {
    accent: "#16908b", accentDark: "#0c6c69", soft: "#d3f0e9",
    ink: "#0f2f3b", bg: "#f3faf8", dark: "#0a2c3a"
  },

  phone: "5555550100",
  whatsapp: "525555550100",   /* ← cámbialo por tu número para probar */
  email: "",
  address: "Calle Ejemplo 123, Col. Centro, 00000 Ciudad Demo",
  mapUrl: "",

  hero: {
    title: "Primero te escuchamos. Después cuidamos tu sonrisa.",
    lead: "Revisamos dientes, encías y mordida, y te explicamos las opciones con palabras sencillas. Tú decides.",
    stats: [
      { n: "6 días", l: "a la semana" },
      { n: "2 turnos", l: "al día" }
    ],
    card: { title: "Revisión completa", text: "Dientes, encías y mordida, con el plan explicado paso a paso.", badge: "Te explicamos todo" },
    art: "tooth"
  },

  booking: {
    mode: "whatsapp",
    endpoint: "",
    accessKey: "",
    subject: "Nueva cita desde la web",
    title: "Agenda tu cita",
    serviceLabel: "Motivo",
    extraService: "Revisión general",
    slots: ["10:00", "11:30", "13:00", "16:00", "17:30", "19:00"],
    daysAhead: 5,
    leadMinutes: 60
  },

  /* Lunes cerrado. Martes a sábado turno partido; domingo solo mañana. */
  hours: [
    { label: "Lunes",             days: [1],             closed: true },
    { label: "Martes a sábado",   days: [2, 3, 4, 5, 6], ranges: [["10:00", "14:00"], ["16:00", "20:00"]] },
    { label: "Domingo",           days: [0],             ranges: [["10:00", "14:00"]] }
  ],

  urgent: { title: "¿Tienes una urgencia?", text: "Escríbenos o llámanos y vemos cómo atenderte lo antes posible." },

  services: [
    { name: "Limpieza dental",       desc: "Elimina el sarro y revisa el estado de tus encías.",           price: "Valoración", duration: "" },
    { name: "Blanqueamiento dental", desc: "Aclara el color de tus dientes de forma segura.",              price: "Valoración", duration: "" },
    { name: "Carillas y coronas",    desc: "Mejora la forma, el color y la resistencia de tu sonrisa.",     price: "Valoración", duration: "" },
    { name: "Implantes dentales",    desc: "Reemplaza piezas faltantes con una solución duradera.",         price: "Valoración", duration: "" },
    { name: "Endodoncia",            desc: "Tratamiento de conductos para salvar tu diente.",               price: "Valoración", duration: "" }
  ],

  team: [
    { name: "Dr. Ejemplo",  role: "Odontólogo",  bio: "Te explica el procedimiento, aclara tus dudas y te da seguimiento.", initials: "E", from: "#2cc2bd", to: "#0c6c69" },
    { name: "Dra. Muestra", role: "Odontóloga", bio: "Atención cercana, con recomendaciones claras para cuidar tus tratamientos.", initials: "M", from: "#6aa9e8", to: "#2f5f9e" }
  ],

  faq: [
    { q: "¿Cómo es la primera consulta?", a: "Empezamos escuchándote: qué te molesta y qué quieres mejorar. Después hacemos una revisión completa y te explicamos lo que encontramos y las opciones de tratamiento." },
    { q: "¿Aceptan tarjeta?", a: "Sí, tarjetas de crédito y de débito." },
    { q: "¿Cuándo abren?", a: "De martes a sábado de 10 a 2 y de 4 a 8, y los domingos de 10 a 2. Los lunes cerramos." }
  ],

  beforeAfter: { enabled: true, title: "Mira la diferencia.", text: "Arrastra la barra. Ilustración de ejemplo de un blanqueamiento.", note: "Ilustración de ejemplo; los resultados varían según cada paciente." },

  privacyUrl: "aviso-privacidad.html",
  demo: true,
  demoNote: "Sitio de demostración. Todos los datos son ficticios."
};
