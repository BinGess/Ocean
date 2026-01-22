import React from 'react';
import { HashRouter as Router, Routes, Route, useLocation } from 'react-router-dom';
import { Home } from './pages/Home';
import { Records } from './pages/Records';
import { WeeklyReport } from './pages/WeeklyReport';
import { NoteDetail } from './pages/NoteDetail';
import { BottomNav } from './components/BottomNav';

const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const location = useLocation();
    // Hide bottom nav on detail page and weekly report
    const showNav = !['/detail', '/insights'].some(path => location.pathname.includes(path));

    return (
        <div className="relative flex h-full min-h-screen w-full flex-col overflow-hidden max-w-md mx-auto bg-background-light shadow-2xl sm:my-0">
            <main className="flex-1 flex flex-col h-full overflow-hidden relative">
                {children}
            </main>
            {showNav && <BottomNav />}
        </div>
    );
};

const App: React.FC = () => {
    return (
        <Router>
            <Routes>
                <Route path="/" element={<Layout><Home /></Layout>} />
                <Route path="/records" element={<Layout><Records /></Layout>} />
                {/* Insights and Detail pages take over full screen/layout usually in this design style */}
                <Route path="/insights" element={<Layout><WeeklyReport /></Layout>} />
                <Route path="/detail/:id" element={<NoteDetail />} />
            </Routes>
        </Router>
    );
};

export default App;
