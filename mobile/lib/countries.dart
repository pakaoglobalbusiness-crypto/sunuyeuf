/// Pays avec drapeau (emoji) et indicatif téléphonique international.
/// Liste orientée Afrique de l'Ouest + diaspora (Europe, Amériques, Golfe).
class Country {
  final String name;
  final String flag;
  final String dial; // avec le +
  const Country(this.name, this.flag, this.dial);
}

const countries = <Country>[
  Country('Sénégal', '🇸🇳', '+221'),
  Country('France', '🇫🇷', '+33'),
  Country('États-Unis', '🇺🇸', '+1'),
  Country('Canada', '🇨🇦', '+1'),
  Country('Belgique', '🇧🇪', '+32'),
  Country('Suisse', '🇨🇭', '+41'),
  Country('Royaume-Uni', '🇬🇧', '+44'),
  Country('Espagne', '🇪🇸', '+34'),
  Country('Italie', '🇮🇹', '+39'),
  Country('Allemagne', '🇩🇪', '+49'),
  Country('Portugal', '🇵🇹', '+351'),
  Country('Pays-Bas', '🇳🇱', '+31'),
  Country('Maroc', '🇲🇦', '+212'),
  Country('Mauritanie', '🇲🇷', '+222'),
  Country('Mali', '🇲🇱', '+223'),
  Country('Guinée', '🇬🇳', '+224'),
  Country('Côte d’Ivoire', '🇨🇮', '+225'),
  Country('Burkina Faso', '🇧🇫', '+226'),
  Country('Niger', '🇳🇪', '+227'),
  Country('Togo', '🇹🇬', '+228'),
  Country('Bénin', '🇧🇯', '+229'),
  Country('Gambie', '🇬🇲', '+220'),
  Country('Guinée-Bissau', '🇬🇼', '+245'),
  Country('Cap-Vert', '🇨🇻', '+238'),
  Country('Ghana', '🇬🇭', '+233'),
  Country('Nigéria', '🇳🇬', '+234'),
  Country('Cameroun', '🇨🇲', '+237'),
  Country('Gabon', '🇬🇦', '+241'),
  Country('Congo', '🇨🇬', '+242'),
  Country('RD Congo', '🇨🇩', '+243'),
  Country('Tchad', '🇹🇩', '+235'),
  Country('Algérie', '🇩🇿', '+213'),
  Country('Tunisie', '🇹🇳', '+216'),
  Country('Égypte', '🇪🇬', '+20'),
  Country('Afrique du Sud', '🇿🇦', '+27'),
  Country('Émirats arabes unis', '🇦🇪', '+971'),
  Country('Arabie saoudite', '🇸🇦', '+966'),
  Country('Qatar', '🇶🇦', '+974'),
  Country('Turquie', '🇹🇷', '+90'),
  Country('Chine', '🇨🇳', '+86'),
  Country('Inde', '🇮🇳', '+91'),
  Country('Brésil', '🇧🇷', '+55'),
];
