import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Disc, FolderOpen, Sparkles } from 'lucide-react';

export const BottomNav: React.FC = () => {
    const navigate = useNavigate();
    const location = useLocation();

    const isActive = (path: string) => location.pathname === path;

    const navItems = [
        { path: '/', label: '记录', icon: Disc, iconSize: 26 },
        { path: '/records', label: '日记', icon: FolderOpen, iconSize: 26 },
        { path: '/insights', label: '洞察', icon: Sparkles, iconSize: 26 },
    ];

    return (
        <nav className="absolute bottom-0 w-full bg-surface-light/95 backdrop-blur-xl border-t border-gray-100 pb-safe z-30">
            <div className="flex justify-around items-center h-16 px-6 pb-2">
                {navItems.map((item) => {
                    const active = isActive(item.path);
                    const Icon = item.icon;
                    return (
                        <button
                            key={item.path}
                            onClick={() => navigate(item.path)}
                            className={`flex flex-col items-center gap-1.5 w-16 transition-colors group ${
                                active ? 'text-primary' : 'text-gray-400 hover:text-gray-600'
                            }`}
                        >
                            <Icon 
                                size={item.iconSize} 
                                strokeWidth={active ? 2.5 : 2}
                                className={`transition-transform duration-200 ${active ? 'scale-110' : 'group-hover:scale-105'}`}
                                fill={active ? 'currentColor' : 'none'}
                            />
                            <span className={`text-[12px] ${active ? 'font-bold' : 'font-medium'}`}>
                                {item.label}
                            </span>
                        </button>
                    );
                })}
            </div>
            <style>{`
                .pb-safe {
                    padding-bottom: env(safe-area-inset-bottom, 20px);
                }
            `}</style>
        </nav>
    );
};