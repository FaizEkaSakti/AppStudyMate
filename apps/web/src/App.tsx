import { FormEvent, useEffect, useState } from "react";
import {
  Activity, ArrowDownRight, ArrowUpRight, BookOpen, Check, ChevronDown, ChevronRight, CircleHelp,
  Code2, ExternalLink, Github, GraduationCap, LayoutDashboard, LoaderCircle, Pencil, Plus,
  RefreshCw, Search, Settings2, Trash2, Users, X
} from "lucide-react";
import {
  ActivityStatus, Commit, Course, CourseDashboardResponse, CourseSyncResponse, Repository, Student,
  StudentProgressResponse, SyncResult
} from "@app-studymate/shared";
import { apiRequest } from "./lib/api";

type Page = "dashboard" | "courses" | "students" | "repositories" | "progress";
type EditorKind = "course" | "student" | "repository";
type EditorState = { Kind: EditorKind; Value: Record<string, string | boolean> } | null;

const Navigation = [
  { Id: "dashboard" as const, Label: "Ringkasan", Icon: LayoutDashboard },
  { Id: "courses" as const, Label: "Kelas", Icon: BookOpen },
  { Id: "students" as const, Label: "Mahasiswa", Icon: Users },
  { Id: "repositories" as const, Label: "Repositori", Icon: Code2 }
];

function formatDate(value: string | null | undefined): string {
  if (!value) return "Belum ada";
  return new Intl.DateTimeFormat("id-ID", { day: "numeric", month: "short", year: "numeric" }).format(new Date(value));
}

function StatusBadge({ Status }: { Status: ActivityStatus }) {
  const Labels = {
    [ActivityStatus.ACTIVE]: "Aktif",
    [ActivityStatus.INACTIVE]: "Tidak aktif",
    [ActivityStatus.NO_COMMIT]: "Belum ada commit"
  };
  return <span className={`status-badge status-${Status.toLowerCase()}`}><span />{Labels[Status]}</span>;
}

function App() {
  const [page, setPage] = useState<Page>("dashboard");
  const [courses, setCourses] = useState<Course[]>([]);
  const [courseId, setCourseId] = useState("");
  const [dashboard, setDashboard] = useState<CourseDashboardResponse | null>(null);
  const [students, setStudents] = useState<Student[]>([]);
  const [studentId, setStudentId] = useState("");
  const [repositories, setRepositories] = useState<Repository[]>([]);
  const [progress, setProgress] = useState<StudentProgressResponse | null>(null);
  const [editor, setEditor] = useState<EditorState>(null);
  const [loading, setLoading] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");

  async function loadCourses() {
    const result = await apiRequest<Course[]>("/courses");
    setCourses(result);
    setCourseId((current) => current || result[0]?.Id || "");
  }

  async function loadDashboard() {
    if (!courseId) { setDashboard(null); return; }
    setLoading(true);
    try { setDashboard(await apiRequest<CourseDashboardResponse>(`/courses/${courseId}/dashboard`)); }
    catch (requestError) { setError((requestError as Error).message); }
    finally { setLoading(false); }
  }

  async function loadStudents() {
    if (!courseId) { setStudents([]); return; }
    setLoading(true);
    try {
      const result = await apiRequest<Student[]>(`/courses/${courseId}/students`);
      setStudents(result);
      setStudentId((current) => result.some((student) => student.Id === current) ? current : result[0]?.Id || "");
    } catch (requestError) { setError((requestError as Error).message); }
    finally { setLoading(false); }
  }

  async function loadRepositories() {
    if (!studentId) { setRepositories([]); return; }
    setLoading(true);
    try { setRepositories(await apiRequest<Repository[]>(`/students/${studentId}/repositories`)); }
    catch (requestError) { setError((requestError as Error).message); }
    finally { setLoading(false); }
  }

  async function loadProgress(id: string) {
    setStudentId(id);
    setPage("progress");
    setLoading(true);
    try { setProgress(await apiRequest<StudentProgressResponse>(`/students/${id}/progress`)); }
    catch (requestError) { setError((requestError as Error).message); }
    finally { setLoading(false); }
  }

  useEffect(() => { loadCourses().catch((requestError) => setError((requestError as Error).message)); }, []);
  useEffect(() => { setError(""); setMessage(""); loadDashboard(); }, [courseId]);
  useEffect(() => { if (page === "students" || page === "repositories") loadStudents(); }, [courseId, page]);
  useEffect(() => { if (page === "repositories") loadRepositories(); }, [studentId, page]);

  async function saveEditor(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!editor) return;
    const data = Object.fromEntries(new FormData(event.currentTarget).entries());
    const body = editor.Kind === "course"
      ? { Name: data.Name, Semester: data.Semester, Year: Number(data.Year) }
      : editor.Kind === "student"
        ? { StudentNumber: data.StudentNumber, Name: data.Name, Email: data.Email, GithubUsername: data.GithubUsername }
        : { Name: data.Name, RepositoryUrl: data.RepositoryUrl, IsActive: data.IsActive === "on" };
    try {
      if (editor.Kind === "course") {
        const id = String(editor.Value.Id ?? "");
        await apiRequest(`/courses${id ? `/${id}` : ""}`, { method: id ? "PUT" : "POST", body: JSON.stringify(body) });
        await loadCourses();
      } else if (editor.Kind === "student") {
        const id = String(editor.Value.Id ?? "");
        await apiRequest(id ? `/students/${id}` : `/courses/${courseId}/students`, {
          method: id ? "PUT" : "POST", body: JSON.stringify(body)
        });
        await loadStudents();
      } else {
        const id = String(editor.Value.Id ?? "");
        await apiRequest(id ? `/repositories/${id}` : `/students/${studentId}/repositories`, {
          method: id ? "PUT" : "POST", body: JSON.stringify(body)
        });
        await loadRepositories();
      }
      setEditor(null);
      setMessage("Perubahan berhasil disimpan.");
      if (page === "dashboard") await loadDashboard();
    } catch (requestError) { setError((requestError as Error).message); }
  }

  async function deleteItem(kind: "course" | "student" | "repository", id: string, label: string) {
    if (!window.confirm(`Hapus ${label}? Data terkait juga dapat terhapus.`)) return;
    try {
      const path = kind === "course" ? `/courses/${id}` : kind === "student" ? `/students/${id}` : `/repositories/${id}`;
      await apiRequest(path, { method: "DELETE" });
      if (kind === "course") await loadCourses();
      if (kind === "student") await loadStudents();
      if (kind === "repository") await loadRepositories();
      setMessage(`${label} berhasil dihapus.`);
    } catch (requestError) { setError((requestError as Error).message); }
  }

  async function syncAll() {
    if (!courseId) return;
    setSyncing(true);
    setError("");
    try {
      const result = await apiRequest<CourseSyncResponse>(`/courses/${courseId}/sync`, { method: "POST" });
      const failures = result.Results.filter((item) => !("NewCommitCount" in item));
      setMessage(`${result.SyncedRepositoryCount} repositori selesai disinkronkan${failures.length ? `, ${failures.length} gagal` : ""}.`);
      if (failures.length) setError(failures.map((item) => item.Message).join(" "));
      await loadDashboard();
    } catch (requestError) { setError((requestError as Error).message); }
    finally { setSyncing(false); }
  }

  async function syncRepository(repository: Repository) {
    setSyncing(true);
    setError("");
    try {
      const result = await apiRequest<SyncResult>(`/repositories/${repository.Id}/sync`, { method: "POST" });
      setMessage(`${repository.Name}: ${result.Message}`);
      await loadRepositories();
    } catch (requestError) { setError((requestError as Error).message); }
    finally { setSyncing(false); }
  }

  const selectedCourse = courses.find((course) => course.Id === courseId);
  const visibleStudents = students.filter((student) =>
    `${student.Name} ${student.StudentNumber} ${student.GithubUsername}`.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <a className="brand" href="#dashboard" onClick={() => setPage("dashboard")}>
          <span className="brand-mark"><GraduationCap size={21} /></span>
          <span>AppStudy<span>Mate</span><small>RUANG BELAJAR</small></span>
        </a>
        <div className="side-label">RUANG KERJA</div>
        <nav className="side-nav">
          {Navigation.map(({ Id, Label, Icon }) => (
            <button key={Id} className={page === Id ? "nav-item selected" : "nav-item"} onClick={() => setPage(Id)}>
              <Icon size={18} strokeWidth={1.8} /><span>{Label}</span>{page === Id && <span className="nav-indicator" />}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="sync-note"><span className="sync-dot" /><div><strong>Sinkronisasi manual</strong><small>Data GitHub diperbarui saat diminta</small></div></div>
          <div className="profile-mini"><div className="avatar">M</div><div><strong>Mahasiswa</strong><small>Akun AppStudyMate</small></div><Settings2 size={16} /></div>
        </div>
      </aside>

      <main className="main-area">
        <header className="topbar">
          <div className="breadcrumb"><span>AppStudyMate</span><ChevronRight size={14} /><strong>{Navigation.find((item) => item.Id === page)?.Label ?? "Progres mahasiswa"}</strong></div>
          <div className="topbar-right"><span className="today-label">{new Intl.DateTimeFormat("id-ID", { weekday: "long", day: "numeric", month: "long" }).format(new Date())}</span><button className="icon-button" title="Bantuan"><CircleHelp size={18} /></button><div className="avatar avatar-small">M</div></div>
        </header>

        <div className="content-wrap">
          {(error || message) && <div className={error ? "notice notice-error" : "notice notice-success"}><span>{error || message}</span><button onClick={() => { setError(""); setMessage(""); }} aria-label="Tutup"><X size={16} /></button></div>}
          {page === "dashboard" && <>
            <div className="page-heading heading-row"><div><div className="eyebrow">PEMANTAUAN KELAS</div><h1>Ringkasan progres</h1><p>Pantau perkembangan repositori mahasiswa dalam satu tempat.</p></div>
              <button className="button button-primary" onClick={syncAll} disabled={!courseId || syncing}><RefreshCw size={16} className={syncing ? "spin" : ""} />{syncing ? "Menyinkronkan..." : "Sinkronkan semua repositori"}</button></div>
            <div className="toolbar"><label className="select-wrap"><BookOpen size={16} /><select value={courseId} onChange={(event) => setCourseId(event.target.value)}><option value="">Pilih kelas</option>{courses.map((course) => <option key={course.Id} value={course.Id}>{course.Name} · {course.Semester} {course.Year}</option>)}</select><ChevronDown size={15} /></label>
              {selectedCourse && <button className="text-button" onClick={() => setPage("courses")}>Kelola kelas <ChevronRight size={15} /></button>}
            </div>
            {loading && !dashboard ? <Loading /> : dashboard ? <>
              <div className="stat-grid">
                <StatCard Label="Mahasiswa" Value={dashboard.Summary.TotalStudents} Icon={Users} Accent="green" Detail="Terdaftar di kelas" />
                <StatCard Label="Repositori" Value={dashboard.Summary.TotalRepositories} Icon={Code2} Accent="ink" Detail="Seluruh repositori" />
                <StatCard Label="Total commit" Value={dashboard.Summary.TotalCommits} Icon={Activity} Accent="orange" Detail="Tersimpan di database" />
                <StatCard Label="Mahasiswa aktif" Value={dashboard.Summary.ActiveStudents} Icon={ArrowUpRight} Accent="green" Detail="Aktif dalam 14 hari" />
                <StatCard Label="Belum ada commit" Value={dashboard.Summary.StudentsWithoutCommits} Icon={ArrowDownRight} Accent="red" Detail="Perlu pemantauan" />
              </div>
              <section className="panel progress-panel">
                <div className="panel-heading"><div><h2>Aktivitas mahasiswa</h2><p>{dashboard.Course.Name} · Semester {dashboard.Course.Semester} {dashboard.Course.Year}</p></div><button className="button button-secondary" onClick={loadDashboard}><RefreshCw size={15} />Muat ulang</button></div>
                <StudentTable Students={dashboard.Students} onOpen={loadProgress} />
              </section>
            </> : <EmptyState Title="Belum ada kelas" Detail="Buat kelas pertama untuk mulai memantau progres mahasiswa." Action="Tambah kelas" onAction={() => setEditor({ Kind: "course", Value: {} })} />}
          </>}

          {page === "courses" && <>
            <div className="page-heading heading-row"><div><div className="eyebrow">PENGELOLAAN AKADEMIK</div><h1>Daftar kelas</h1><p>Atur kelas dan akses ringkasan progres setiap kelas.</p></div><button className="button button-primary" onClick={() => setEditor({ Kind: "course", Value: {} })}><Plus size={17} />Tambah kelas</button></div>
            <section className="panel"><div className="panel-heading"><div><h2>Kelas terdaftar</h2><p>{courses.length} kelas pada workspace</p></div></div>
              {courses.length ? <div className="table-scroll"><table><thead><tr><th>NAMA KELAS</th><th>SEMESTER</th><th>TAHUN</th><th>DIBUAT</th><th></th></tr></thead><tbody>{courses.map((course) => <tr key={course.Id}><td><strong>{course.Name}</strong></td><td>{course.Semester}</td><td>{course.Year}</td><td>{formatDate(course.CreatedAt)}</td><td className="row-actions"><button className="button button-small" onClick={() => { setCourseId(course.Id); setPage("dashboard"); }}>Buka ringkasan <ChevronRight size={14} /></button><button className="icon-button" title="Ubah kelas" onClick={() => setEditor({ Kind: "course", Value: { Id: course.Id, Name: course.Name, Semester: course.Semester, Year: String(course.Year) } })}><Pencil size={15} /></button><button className="icon-button danger-hover" title="Hapus kelas" onClick={() => deleteItem("course", course.Id, "kelas ini")}><Trash2 size={15} /></button></td></tr>)}</tbody></table></div> : <EmptyState Title="Belum ada kelas" Detail="Tambahkan kelas untuk mengelola mahasiswa." Action="Tambah kelas" onAction={() => setEditor({ Kind: "course", Value: {} })} />}
            </section>
          </>}

          {page === "students" && <>
            <div className="page-heading heading-row"><div><div className="eyebrow">DATA KELAS</div><h1>Mahasiswa</h1><p>Kelola identitas dan akun GitHub mahasiswa.</p></div><button className="button button-primary" disabled={!courseId} onClick={() => setEditor({ Kind: "student", Value: {} })}><Plus size={17} />Tambah mahasiswa</button></div>
            <div className="toolbar"><label className="select-wrap"><BookOpen size={16} /><select value={courseId} onChange={(event) => setCourseId(event.target.value)}><option value="">Pilih kelas</option>{courses.map((course) => <option key={course.Id} value={course.Id}>{course.Name} · {course.Year}</option>)}</select><ChevronDown size={15} /></label><label className="search-wrap"><Search size={16} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Cari nama atau nomor mahasiswa" /></label></div>
            <section className="panel"><div className="panel-heading"><div><h2>Daftar mahasiswa</h2><p>{visibleStudents.length} mahasiswa</p></div></div>
              {loading ? <Loading /> : visibleStudents.length ? <div className="table-scroll"><table><thead><tr><th>MAHASISWA</th><th>NOMOR</th><th>EMAIL</th><th>GITHUB</th><th></th></tr></thead><tbody>{visibleStudents.map((student) => <tr key={student.Id}><td><button className="student-link" onClick={() => loadProgress(student.Id)}><span className="avatar avatar-table">{student.Name.split(" ").map((part) => part[0]).slice(0, 2).join("")}</span><strong>{student.Name}</strong></button></td><td>{student.StudentNumber}</td><td>{student.Email}</td><td><a className="github-link" href={`https://github.com/${student.GithubUsername}`} target="_blank" rel="noreferrer"><Github size={15} />{student.GithubUsername}<ExternalLink size={12} /></a></td><td className="row-actions"><button className="button button-small" onClick={() => { setStudentId(student.Id); setPage("repositories"); }}>Repositori</button><button className="icon-button" title="Ubah mahasiswa" onClick={() => setEditor({ Kind: "student", Value: { Id: student.Id, Name: student.Name, StudentNumber: student.StudentNumber, Email: student.Email, GithubUsername: student.GithubUsername } })}><Pencil size={15} /></button><button className="icon-button danger-hover" title="Hapus mahasiswa" onClick={() => deleteItem("student", student.Id, "mahasiswa ini")}><Trash2 size={15} /></button></td></tr>)}</tbody></table></div> : <EmptyState Title="Mahasiswa belum tersedia" Detail="Tambahkan mahasiswa ke kelas yang dipilih." Action="Tambah mahasiswa" onAction={() => setEditor({ Kind: "student", Value: {} })} />}
            </section>
          </>}

          {page === "repositories" && <>
            <div className="page-heading heading-row"><div><div className="eyebrow">SUMBER AKTIVITAS</div><h1>Repositori GitHub</h1><p>Daftarkan repo publik dan perbarui data commit saat diperlukan.</p></div><button className="button button-primary" disabled={!studentId} onClick={() => setEditor({ Kind: "repository", Value: { IsActive: true } })}><Plus size={17} />Tambah repositori</button></div>
            <div className="toolbar"><label className="select-wrap"><Users size={16} /><select value={studentId} onChange={(event) => setStudentId(event.target.value)}><option value="">Pilih mahasiswa</option>{students.map((student) => <option key={student.Id} value={student.Id}>{student.Name} · {student.StudentNumber}</option>)}</select><ChevronDown size={15} /></label>{students.find((item) => item.Id === studentId) && <button className="text-button" onClick={() => loadProgress(studentId)}>Lihat progres <ChevronRight size={15} /></button>}</div>
            <section className="panel"><div className="panel-heading"><div><h2>Repositori terhubung</h2><p>{students.find((item) => item.Id === studentId)?.Name ?? "Pilih mahasiswa"}</p></div></div>
              {loading ? <Loading /> : repositories.length ? <div className="table-scroll"><table><thead><tr><th>REPOSITORI</th><th>STATUS</th><th>COMMIT TERSIMPAN</th><th>SINKRON TERAKHIR</th><th></th></tr></thead><tbody>{repositories.map((repository) => <tr key={repository.Id}><td><a className="repo-link" href={repository.RepositoryUrl} target="_blank" rel="noreferrer"><Github size={16} /><span><strong>{repository.Name}</strong><small>{repository.Owner}/{repository.RepositoryName}</small></span><ExternalLink size={13} /></a></td><td><span className={repository.IsActive ? "repo-state on" : "repo-state off"}>{repository.IsActive ? "Aktif" : "Nonaktif"}</span></td><td>{repository.CommitCount ?? 0}</td><td>{formatDate(repository.LastSyncedAt)}</td><td className="row-actions"><button className="button button-small button-sync" disabled={syncing} onClick={() => syncRepository(repository)}><RefreshCw size={14} className={syncing ? "spin" : ""} />Sinkronkan commit</button><button className="icon-button" title="Ubah repositori" onClick={() => setEditor({ Kind: "repository", Value: { Id: repository.Id, Name: repository.Name, RepositoryUrl: repository.RepositoryUrl, IsActive: repository.IsActive } })}><Pencil size={15} /></button><button className="icon-button danger-hover" title="Hapus repositori" onClick={() => deleteItem("repository", repository.Id, "repositori ini")}><Trash2 size={15} /></button></td></tr>)}</tbody></table></div> : <EmptyState Title="Belum ada repositori" Detail="Tambahkan URL GitHub mahasiswa untuk mulai melacak commit." Action="Tambah repositori" onAction={() => setEditor({ Kind: "repository", Value: { IsActive: true } })} />}
            </section>
            <p className="privacy-note"><Github size={15} />Sinkronisasi hanya berjalan saat tombol ditekan. Riwayat yang sudah disimpan tidak akan ditimpa.</p>
          </>}

          {page === "progress" && <>
            {loading && !progress ? <Loading /> : progress && <>
              <button className="back-link" onClick={() => setPage("students")}>← Kembali ke mahasiswa</button>
              <div className="page-heading progress-heading"><div><div className="eyebrow">PROFIL MAHASISWA</div><h1>{progress.Student.Name}</h1><p>{progress.Student.StudentNumber} <span className="middot">·</span> {progress.Student.Email}</p></div><a className="button button-secondary" href={`https://github.com/${progress.Student.GithubUsername}`} target="_blank" rel="noreferrer"><Github size={16} />{progress.Student.GithubUsername}<ExternalLink size={13} /></a></div>
              <div className="detail-stats"><div><span>Total commit</span><strong>{progress.TotalCommits}</strong></div><div><span>Repositori</span><strong>{progress.Repositories.length}</strong></div><div><span>Commit terbaru</span><strong>{formatDate(progress.LatestCommitAt)}</strong></div></div>
              <section className="panel"><div className="panel-heading"><div><h2>Repositori mahasiswa</h2><p>{progress.Repositories.length} repositori terdaftar</p></div></div>
                {progress.Repositories.length ? <div className="repository-list">{progress.Repositories.map((repository) => <div className="repository-block" key={repository.Id}><div className="repository-block-heading"><a className="repo-link" href={repository.RepositoryUrl} target="_blank" rel="noreferrer"><Github size={17} /><span><strong>{repository.Name}</strong><small>{repository.Owner}/{repository.RepositoryName}</small></span><ExternalLink size={13} /></a><div className="repo-meta"><span>{repository.Commits.length} commit</span><span>Sinkron {formatDate(repository.LastSyncedAt)}</span><StatusBadge Status={repository.Commits.length ? ActivityStatus.ACTIVE : ActivityStatus.NO_COMMIT} /></div></div>
                  {repository.Commits.length ? <div className="table-scroll"><table><thead><tr><th>PESAN COMMIT</th><th>PENULIS</th><th>TANGGAL</th><th>SHA</th><th></th></tr></thead><tbody>{repository.Commits.map((commit: Commit) => <tr key={commit.Id}><td className="commit-message">{commit.Message.split("\n")[0]}</td><td>{commit.AuthorName}</td><td>{formatDate(commit.CommittedAt)}</td><td><code className="sha">{commit.Sha.slice(0, 8)}</code></td><td><a className="icon-button" href={commit.CommitUrl} target="_blank" rel="noreferrer" title="Buka commit di GitHub"><ExternalLink size={15} /></a></td></tr>)}</tbody></table></div> : <div className="inline-empty">Belum ada commit tersimpan untuk repositori ini.</div>}</div>)}</div> : <EmptyState Title="Belum ada repositori" Detail="Tambahkan repositori GitHub dari menu repositori." />}
              </section>
            </>}
          </>}
        </div>
      </main>

      {editor && <EditorModal Editor={editor} onClose={() => setEditor(null)} onSave={saveEditor} />}
    </div>
  );
}

function StatCard({ Label, Value, Icon, Accent, Detail }: { Label: string; Value: number; Icon: typeof Users; Accent: string; Detail: string }) {
  return <div className={`stat-card accent-${Accent}`}><div className="stat-top"><span>{Label}</span><span className="stat-icon"><Icon size={17} /></span></div><strong className="stat-value">{Value}</strong><small>{Detail}</small></div>;
}

function StudentTable({ Students, onOpen }: { Students: CourseDashboardResponse["Students"]; onOpen: (id: string) => void }) {
  if (!Students.length) return <EmptyState Title="Belum ada mahasiswa" Detail="Tambahkan mahasiswa pada kelas ini untuk melihat aktivitasnya." />;
  return <div className="table-scroll"><table><thead><tr><th>MAHASISWA</th><th>NOMOR</th><th>REPOSITORI</th><th>TOTAL COMMIT</th><th>COMMIT TERAKHIR</th><th>STATUS</th><th></th></tr></thead><tbody>{Students.map((student) => <tr key={student.StudentId}><td><button className="student-link" onClick={() => onOpen(student.StudentId)}><span className="avatar avatar-table">{student.StudentName.split(" ").map((part) => part[0]).slice(0, 2).join("")}</span><strong>{student.StudentName}</strong></button></td><td>{student.StudentNumber}</td><td>{student.RepositoryCount}</td><td><strong>{student.TotalCommits}</strong></td><td>{formatDate(student.LatestCommitAt)}</td><td><StatusBadge Status={student.ActivityStatus} /></td><td><button className="icon-button" title="Lihat detail progres" onClick={() => onOpen(student.StudentId)}><ChevronRight size={17} /></button></td></tr>)}</tbody></table></div>;
}

function EmptyState({ Title, Detail, Action, onAction }: { Title: string; Detail: string; Action?: string; onAction?: () => void }) {
  return <div className="empty-state"><span className="empty-icon"><BookOpen size={21} /></span><h3>{Title}</h3><p>{Detail}</p>{Action && onAction && <button className="button button-secondary" onClick={onAction}><Plus size={15} />{Action}</button>}</div>;
}

function Loading() {
  return <div className="loading-state"><LoaderCircle size={20} className="spin" />Memuat data...</div>;
}

function EditorModal({ Editor, onClose, onSave }: { Editor: Exclude<EditorState, null>; onClose: () => void; onSave: (event: FormEvent<HTMLFormElement>) => void }) {
  const Editing = Boolean(Editor.Value.Id);
  const Heading = `${Editing ? "Ubah" : "Tambah"} ${Editor.Kind === "course" ? "kelas" : Editor.Kind === "student" ? "mahasiswa" : "repositori"}`;
  return <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}><form className="editor-modal" onSubmit={onSave}>
    <div className="modal-heading"><div><div className="eyebrow">FORMULIR DATA</div><h2>{Heading}</h2></div><button type="button" className="icon-button" onClick={onClose} aria-label="Tutup"><X size={18} /></button></div>
    {Editor.Kind === "course" && <><Field Label="Nama kelas" Name="Name" Value={Editor.Value.Name} Placeholder="Contoh: Pemrograman Web" /><div className="field-row"><Field Label="Semester" Name="Semester" Value={Editor.Value.Semester} Placeholder="Ganjil" /><Field Label="Tahun" Name="Year" Value={Editor.Value.Year} Type="number" Placeholder="2026" /></div></>}
    {Editor.Kind === "student" && <><Field Label="Nama lengkap" Name="Name" Value={Editor.Value.Name} Placeholder="Nama mahasiswa" /><div className="field-row"><Field Label="Nomor mahasiswa" Name="StudentNumber" Value={Editor.Value.StudentNumber} Placeholder="20260001" /><Field Label="Username GitHub" Name="GithubUsername" Value={Editor.Value.GithubUsername} Placeholder="username" /></div><Field Label="Alamat email" Name="Email" Value={Editor.Value.Email} Type="email" Placeholder="nama@email.com" /></>}
    {Editor.Kind === "repository" && <><Field Label="Nama repositori" Name="Name" Value={Editor.Value.Name} Placeholder="Contoh: tugas-web" /><Field Label="URL repositori GitHub" Name="RepositoryUrl" Value={Editor.Value.RepositoryUrl} Type="url" Placeholder="https://github.com/pemilik/repositori" /><label className="checkbox-field"><input type="checkbox" name="IsActive" defaultChecked={Editor.Value.IsActive !== false} /><span>Repositori aktif dan ikut sinkronisasi kelas</span></label><p className="field-hint">Gunakan repositori publik dengan format URL GitHub yang benar.</p></>}
    <div className="modal-actions"><button type="button" className="button button-secondary" onClick={onClose}>Batal</button><button type="submit" className="button button-primary"><Check size={16} />Simpan data</button></div>
  </form></div>;
}

function Field({ Label, Name, Value, Placeholder, Type = "text" }: { Label: string; Name: string; Value?: string | number | boolean; Placeholder: string; Type?: string }) {
  return <label className="form-field"><span>{Label}</span><input name={Name} type={Type} defaultValue={Value === undefined ? "" : String(Value)} placeholder={Placeholder} required /></label>;
}

export default App;