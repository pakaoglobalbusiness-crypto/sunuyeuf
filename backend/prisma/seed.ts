import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Photos de démo (Unsplash, libres d'utilisation)
const villaPhotos = [
  'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800',
  'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800',
  'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800',
  'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
  'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
  'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800',
];
const carPhotos = [
  'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=800',
  'https://images.unsplash.com/photo-1583121274602-3e2820c69888?w=800',
  'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=800',
  'https://images.unsplash.com/photo-1502877338535-766e1452684a?w=800',
];

async function main() {
  console.log('Seed Gologui…');

  const admin = await prisma.user.upsert({
    where: { phone: '+221770000000' },
    update: { role: 'admin' },
    create: {
      phone: '+221770000000',
      name: 'Admin Gologui',
      role: 'admin',
      kycStatus: 'verified',
    },
  });

  const owners = [] as { id: string }[];
  const ownerData = [
    { phone: '+221771111111', name: 'Awa Ndiaye' },
    { phone: '+221772222222', name: 'Moussa Diop' },
    { phone: '+221773333333', name: 'Fatou Sall' },
  ];
  for (const o of ownerData) {
    owners.push(
      await prisma.user.upsert({
        where: { phone: o.phone },
        update: {},
        create: {
          ...o,
          role: 'owner',
          kycStatus: 'verified',
          payoutMethod: 'wave',
          payoutAccount: o.phone,
        },
      }),
    );
  }

  await prisma.user.upsert({
    where: { phone: '+221774444444' },
    update: {},
    create: { phone: '+221774444444', name: 'Ibrahima Fall', role: 'renter', kycStatus: 'verified' },
  });

  const villas = [
    {
      owner: 0, title: 'Villa Teranga — piscine et vue mer', city: 'Dakar', district: 'Almadies',
      lat: 14.7447, lng: -17.5156, price: 85000,
      description: 'Superbe villa aux Almadies : 4 chambres climatisées, piscine privée, wifi fibre, gardien 24 h/24. Idéale pour familles de la diaspora.',
      details: { bedrooms: 4, bathrooms: 3, capacity: 8, pool: true, wifi: true, ac: true, guard: true },
      photos: [villaPhotos[0], villaPhotos[1]],
    },
    {
      owner: 1, title: 'Maison familiale à Saly, 200 m de la plage', city: 'Saly', district: 'Saly Portudal',
      lat: 14.4472, lng: -17.0083, price: 45000,
      description: 'Maison de 3 chambres dans une résidence sécurisée à Saly. Piscine partagée, climatisation, à 5 min à pied de la plage.',
      details: { bedrooms: 3, bathrooms: 2, capacity: 6, pool: true, wifi: true, ac: true, guard: true },
      photos: [villaPhotos[2], villaPhotos[3]],
    },
    {
      owner: 2, title: 'Appartement cosy — Plateau, Saint-Louis', city: 'Saint-Louis', district: 'Île Nord',
      lat: 16.0326, lng: -16.4818, price: 25000,
      description: 'Charmant appartement dans une maison coloniale rénovée sur l’île de Saint-Louis. 2 chambres, wifi, proche du fleuve.',
      details: { bedrooms: 2, bathrooms: 1, capacity: 4, pool: false, wifi: true, ac: true, guard: false },
      photos: [villaPhotos[4], villaPhotos[5]],
    },
    {
      owner: 0, title: 'Villa moderne à Ngor avec terrasse', city: 'Dakar', district: 'Ngor',
      lat: 14.7532, lng: -17.5142, price: 65000,
      description: 'Villa contemporaine à Ngor : 3 chambres, grande terrasse avec vue sur l’île de Ngor, cuisine équipée, parking sécurisé.',
      details: { bedrooms: 3, bathrooms: 2, capacity: 6, pool: false, wifi: true, ac: true, guard: true },
      photos: [villaPhotos[1], villaPhotos[0]],
    },
  ];

  const cars = [
    {
      owner: 1, title: 'Toyota RAV4 2022 — avec ou sans chauffeur', city: 'Dakar', district: 'Point E',
      lat: 14.7006, lng: -17.4622, price: 35000, deposit: 150000,
      description: 'RAV4 récente, climatisée, idéale pour vos déplacements à Dakar et en région. Remise possible à l’aéroport AIBD.',
      details: { brand: 'Toyota', model: 'RAV4', year: 2022, gearbox: 'automatique', fuel: 'essence', withDriver: true, kmIncludedDay: 200, deliveryPlace: 'aeroport_aibd' },
      photos: [carPhotos[0], carPhotos[1]],
    },
    {
      owner: 2, title: 'Hyundai i10 économique — parfaite en ville', city: 'Dakar', district: 'Ouakam',
      lat: 14.7219, lng: -17.4902, price: 15000, deposit: 75000,
      description: 'Petite citadine fiable et économe, boîte manuelle. Parfaite pour circuler à Dakar. Remise à domicile possible.',
      details: { brand: 'Hyundai', model: 'i10', year: 2021, gearbox: 'manuelle', fuel: 'essence', withDriver: false, kmIncludedDay: 150, deliveryPlace: 'domicile' },
      photos: [carPhotos[2]],
    },
    {
      owner: 0, title: 'Peugeot 3008 — confort pour la route de Saly', city: 'Saly', district: 'Saly Niakh Niakhal',
      lat: 14.4520, lng: -17.0110, price: 28000, deposit: 120000,
      description: 'SUV confortable et récent, climatisation bi-zone. Idéal pour les trajets Dakar–Saly et les vacances en famille.',
      details: { brand: 'Peugeot', model: '3008', year: 2023, gearbox: 'automatique', fuel: 'diesel', withDriver: false, kmIncludedDay: 250, deliveryPlace: 'agence' },
      photos: [carPhotos[3], carPhotos[0]],
    },
  ];

  for (const v of villas) {
    const exists = await prisma.listing.findFirst({ where: { title: v.title } });
    if (exists) continue;
    await prisma.listing.create({
      data: {
        ownerId: owners[v.owner].id,
        type: 'villa',
        title: v.title,
        description: v.description,
        city: v.city,
        district: v.district,
        lat: v.lat,
        lng: v.lng,
        pricePerDayFcfa: v.price,
        cancellationPolicy: 'moderate',
        instantBooking: v.owner === 0,
        status: 'published',
        villaDetails: { create: v.details },
        photos: { create: v.photos.map((url, order) => ({ url, order })) },
      },
    });
  }

  for (const c of cars) {
    const exists = await prisma.listing.findFirst({ where: { title: c.title } });
    if (exists) continue;
    await prisma.listing.create({
      data: {
        ownerId: owners[c.owner].id,
        type: 'voiture',
        title: c.title,
        description: c.description,
        city: c.city,
        district: c.district,
        lat: c.lat,
        lng: c.lng,
        pricePerDayFcfa: c.price,
        depositFcfa: c.deposit,
        cancellationPolicy: 'flexible',
        instantBooking: true,
        status: 'published',
        carDetails: { create: c.details },
        photos: { create: c.photos.map((url, order) => ({ url, order })) },
      },
    });
  }

  console.log('Seed terminé.');
  console.log(`Admin : +221 77 000 00 00 (id ${admin.id})`);
  console.log('Propriétaires : +221771111111 / +221772222222 / +221773333333');
  console.log('Locataire démo : +221774444444');
}

main().finally(() => prisma.$disconnect());
