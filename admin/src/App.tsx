import { useEffect, useState } from 'react';
import {
  BrowserRouter,
  NavLink,
  Navigate,
  Route,
  Routes,
  useNavigate,
} from 'react-router-dom';
import { api, fcfa, getToken, setToken } from './api';

// ---------- Connexion (OTP admin) ----------

function Login() {
  const [phone, setPhone] = useState('+221770000000');
  const [code, setCode] = useState('');
  const [devCode, setDevCode] = useState<string | null>(null);
  const [step, setStep] = useState<'phone' | 'code'>('phone');
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const requestOtp = async () => {
    setError('');
    try {
      const r = await api<{ devCode?: string }>('/auth/otp/request', {
        method: 'POST',
        body: { phone },
      });
      setDevCode(r.devCode ?? null);
      setStep('code');
    } catch (e) {
      setError((e as Error).message);
    }
  };

  const verify = async () => {
    setError('');
    try {
      const r = await api<{ token: string; user: { role: string } }>(
        '/auth/otp/verify',
        { method: 'POST', body: { phone, code } },
      );
      if (r.user.role !== 'admin') {
        setError('Ce compte n’est pas administrateur');
        return;
      }
      setToken(r.token);
      navigate('/');
    } catch (e) {
      setError((e as Error).message);
    }
  };

  return (
    <div className="login-page">
      <div className="login-box">
        <h1>
          Sunu<span>yeuf</span>
        </h1>
        <p>Back-office administration</p>
        {error && <div className="error">{error}</div>}
        {step === 'phone' ? (
          <>
            <input
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+221 7X XXX XX XX"
            />
            <button className="primary" onClick={requestOtp}>
              Recevoir le code SMS
            </button>
          </>
        ) : (
          <>
            {devCode && (
              <div className="hint">
                Mode dev — code OTP : <strong>{devCode}</strong>
              </div>
            )}
            <input
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="Code à 6 chiffres"
              maxLength={6}
            />
            <button className="primary" onClick={verify}>
              Se connecter
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// ---------- Tableau de bord (F21) ----------

interface Stats {
  users: number;
  listings: number;
  publishedListings: number;
  bookings: number;
  paidBookings: number;
  gmvFcfa: number;
  commissionFcfa: number;
  openDisputes: number;
  topCities: { city: string; gmvFcfa: number }[];
}

function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  useEffect(() => {
    api<Stats>('/admin/stats').then(setStats).catch(console.error);
  }, []);
  if (!stats) return <div className="empty">Chargement…</div>;
  return (
    <>
      <h2>Tableau de bord</h2>
      <div className="cards">
        <div className="stat-card"><div className="label">GMV</div><div className="value">{fcfa(stats.gmvFcfa)}</div></div>
        <div className="stat-card"><div className="label">Commission (10 %)</div><div className="value">{fcfa(stats.commissionFcfa)}</div></div>
        <div className="stat-card"><div className="label">Réservations payées</div><div className="value">{stats.paidBookings} / {stats.bookings}</div></div>
        <div className="stat-card"><div className="label">Utilisateurs</div><div className="value">{stats.users}</div></div>
        <div className="stat-card"><div className="label">Annonces publiées</div><div className="value">{stats.publishedListings} / {stats.listings}</div></div>
        <div className="stat-card"><div className="label">Litiges ouverts</div><div className="value">{stats.openDisputes}</div></div>
      </div>
      <h2>Top villes (GMV)</h2>
      <table>
        <thead><tr><th>Ville</th><th>GMV</th></tr></thead>
        <tbody>
          {stats.topCities.length === 0 && (
            <tr><td colSpan={2} className="empty">Aucune transaction pour le moment</td></tr>
          )}
          {stats.topCities.map((c) => (
            <tr key={c.city}><td>{c.city}</td><td>{fcfa(c.gmvFcfa)}</td></tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

// ---------- Modération des annonces (F19) ----------

interface ModListing {
  id: string;
  type: string;
  title: string;
  description: string;
  city: string;
  district?: string;
  pricePerDayFcfa: number;
  photos: { url: string }[];
  owner: { name?: string; phone: string; kycStatus: string };
}

function Moderation() {
  const [items, setItems] = useState<ModListing[]>([]);
  const load = () =>
    api<ModListing[]>('/admin/listings/moderation').then(setItems).catch(console.error);
  useEffect(() => { load(); }, []);

  const decide = async (id: string, decision: string) => {
    await api(`/admin/listings/${id}/moderate`, { method: 'POST', body: { decision } });
    load();
  };

  return (
    <>
      <h2>Annonces en modération</h2>
      {items.length === 0 && <div className="empty">Aucune annonce en attente ✅</div>}
      {items.map((l) => (
        <div className="card" key={l.id}>
          <h3>{l.title}</h3>
          <div className="meta">
            {l.type === 'villa' ? '🏠 Villa' : '🚗 Voiture'} · {l.city}
            {l.district ? ` (${l.district})` : ''} · {fcfa(l.pricePerDayFcfa)}/jour ·
            Propriétaire : {l.owner.name ?? l.owner.phone}{' '}
            <span className={`badge ${l.owner.kycStatus === 'verified' ? 'green' : 'red'}`}>
              KYC {l.owner.kycStatus}
            </span>
          </div>
          <div className="row" style={{ marginBottom: 10 }}>
            {l.photos.map((p, i) => (
              <img key={i} src={p.url} alt="" />
            ))}
          </div>
          <p style={{ fontSize: 14, marginBottom: 12 }}>{l.description}</p>
          <div className="row">
            <button className="primary" onClick={() => decide(l.id, 'approve')}>Publier</button>
            <button className="danger" onClick={() => decide(l.id, 'reject')}>Refuser</button>
          </div>
        </div>
      ))}
    </>
  );
}

// ---------- KYC ----------

interface KycDoc {
  id: string;
  type: string;
  fileUrl: string;
  user: { id: string; name?: string; phone: string };
}

function Kyc() {
  const [docs, setDocs] = useState<KycDoc[]>([]);
  const load = () => api<KycDoc[]>('/admin/kyc/pending').then(setDocs).catch(console.error);
  useEffect(() => { load(); }, []);

  const decide = async (id: string, decision: string) => {
    await api(`/admin/kyc/${id}/review`, { method: 'POST', body: { decision } });
    load();
  };

  return (
    <>
      <h2>Documents KYC en attente</h2>
      {docs.length === 0 && <div className="empty">Aucun document en attente ✅</div>}
      {docs.map((d) => (
        <div className="card" key={d.id}>
          <h3>{d.user.name ?? d.user.phone}</h3>
          <div className="meta">
            Document : <strong>{d.type.toUpperCase()}</strong> ·{' '}
            <a href={d.fileUrl} target="_blank" rel="noreferrer">Voir le fichier</a>
          </div>
          <div className="row">
            <button className="primary" onClick={() => decide(d.id, 'approve')}>Approuver</button>
            <button className="danger" onClick={() => decide(d.id, 'reject')}>Rejeter</button>
          </div>
        </div>
      ))}
    </>
  );
}

// ---------- Litiges (F20) ----------

interface DisputeItem {
  id: string;
  reason: string;
  createdAt: string;
  openedBy: { name?: string };
  booking: {
    id: string;
    totalPriceFcfa: number;
    listing: { title: string };
    renter: { name?: string; phone: string };
  };
}

function Disputes() {
  const [items, setItems] = useState<DisputeItem[]>([]);
  const load = () => api<DisputeItem[]>('/admin/disputes').then(setItems).catch(console.error);
  useEffect(() => { load(); }, []);

  const resolve = async (d: DisputeItem, decision: 'resolved' | 'rejected') => {
    const resolution = window.prompt('Résolution (visible par les parties) :') ?? '';
    if (!resolution) return;
    let refundFcfa: number | undefined;
    if (decision === 'resolved') {
      const r = window.prompt('Remboursement au locataire en FCFA (0 si aucun) :', '0');
      refundFcfa = r ? parseInt(r, 10) || 0 : 0;
    }
    await api(`/admin/disputes/${d.id}/resolve`, {
      method: 'POST',
      body: { decision, resolution, refundFcfa },
    });
    load();
  };

  return (
    <>
      <h2>Litiges ouverts</h2>
      {items.length === 0 && <div className="empty">Aucun litige ouvert ✅</div>}
      {items.map((d) => (
        <div className="card" key={d.id}>
          <h3>{d.booking.listing.title}</h3>
          <div className="meta">
            Ouvert par {d.openedBy.name ?? 'inconnu'} ·{' '}
            {new Date(d.createdAt).toLocaleDateString('fr-FR')} · Montant :{' '}
            {fcfa(d.booking.totalPriceFcfa)} · Locataire :{' '}
            {d.booking.renter.name ?? d.booking.renter.phone}
          </div>
          <p style={{ fontSize: 14, marginBottom: 12 }}>« {d.reason} »</p>
          <div className="row">
            <button className="primary" onClick={() => resolve(d, 'resolved')}>Résoudre</button>
            <button className="neutral" onClick={() => resolve(d, 'rejected')}>Rejeter</button>
          </div>
        </div>
      ))}
    </>
  );
}

// ---------- Utilisateurs ----------

interface UserRow {
  id: string;
  phone: string;
  name?: string;
  role: string;
  kycStatus: string;
  blocked: boolean;
  createdAt: string;
}

function Users() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [q, setQ] = useState('');
  const load = (query = '') =>
    api<UserRow[]>(`/admin/users${query ? `?q=${encodeURIComponent(query)}` : ''}`)
      .then(setUsers)
      .catch(console.error);
  useEffect(() => { load(); }, []);

  const toggleBlock = async (u: UserRow) => {
    await api(`/admin/users/${u.id}/block`, { method: 'POST', body: { blocked: !u.blocked } });
    load(q);
  };

  return (
    <>
      <h2>Utilisateurs</h2>
      <div className="row" style={{ marginBottom: 14 }}>
        <input
          style={{ padding: 9, borderRadius: 8, border: '1px solid var(--border)', width: 280 }}
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Recherche nom ou téléphone"
        />
        <button className="primary" onClick={() => load(q)}>Rechercher</button>
      </div>
      <table>
        <thead>
          <tr><th>Nom</th><th>Téléphone</th><th>Rôle</th><th>KYC</th><th>Statut</th><th></th></tr>
        </thead>
        <tbody>
          {users.map((u) => (
            <tr key={u.id}>
              <td>{u.name ?? '—'}</td>
              <td>{u.phone}</td>
              <td>{u.role}</td>
              <td>
                <span className={`badge ${u.kycStatus === 'verified' ? 'green' : 'gray'}`}>
                  {u.kycStatus}
                </span>
              </td>
              <td>
                <span className={`badge ${u.blocked ? 'red' : 'green'}`}>
                  {u.blocked ? 'bloqué' : 'actif'}
                </span>
              </td>
              <td>
                {u.role !== 'admin' && (
                  <button
                    className={u.blocked ? 'primary' : 'danger'}
                    onClick={() => toggleBlock(u)}
                  >
                    {u.blocked ? 'Débloquer' : 'Bloquer'}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}

// ---------- Layout ----------

function Shell({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  return (
    <div className="layout">
      <nav className="sidebar">
        <h1>Sunu<span>yeuf</span></h1>
        <NavLink to="/" end>📊 Tableau de bord</NavLink>
        <NavLink to="/moderation">🛡️ Modération</NavLink>
        <NavLink to="/kyc">🪪 KYC</NavLink>
        <NavLink to="/disputes">⚖️ Litiges</NavLink>
        <NavLink to="/users">👥 Utilisateurs</NavLink>
        <button onClick={() => { setToken(null); navigate('/login'); }}>
          Déconnexion
        </button>
      </nav>
      <main className="content">{children}</main>
    </div>
  );
}

function Protected({ children }: { children: React.ReactNode }) {
  if (!getToken()) return <Navigate to="/login" replace />;
  return <Shell>{children}</Shell>;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<Protected><Dashboard /></Protected>} />
        <Route path="/moderation" element={<Protected><Moderation /></Protected>} />
        <Route path="/kyc" element={<Protected><Kyc /></Protected>} />
        <Route path="/disputes" element={<Protected><Disputes /></Protected>} />
        <Route path="/users" element={<Protected><Users /></Protected>} />
      </Routes>
    </BrowserRouter>
  );
}
