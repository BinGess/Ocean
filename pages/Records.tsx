import React from 'react';
import { Settings } from 'lucide-react';
import { DailyCard } from '../components/DailyCard';
import { JournalEntry, Mood } from '../types';
import { useNavigate } from 'react-router-dom';

// Hardcoded Data
const SAMPLE_DATA: JournalEntry[] = [
    {
        id: '1',
        date: '10月23日',
        dayOfWeek: '周一',
        isYesterday: true,
        moods: [Mood.HighPleasure, Mood.LowAnxiety],
        summary: "今天的会议后，我的看法改变了。AI 洞察建议我停止往坏处想，而是寻求具体的反馈。当我的“清晰”需求得到满足时，这种直接的沟通让我感到无比释然。",
        quickNotes: [
            { id: 'n1', type: 'audio', duration: '0:42', timestamp: '9:41', progress: 66 },
            { id: 'n2', type: 'text', content: "午饭前感觉很匆忙...", timestamp: '12:30' },
            { id: 'n3', type: 'audio', duration: '0:15', timestamp: '16:15', progress: 50 },
        ]
    },
    {
        id: '2',
        date: '10月22日',
        dayOfWeek: '周日',
        moods: [Mood.Calm],
        summary: "",
        quickNotes: [
            { id: 'n4', type: 'text', content: "清单越来越多...", timestamp: '10:00' },
        ]
    }
];

export const Records: React.FC = () => {
    const navigate = useNavigate();

    return (
        <div className="flex-1 overflow-y-auto px-5 pb-32 no-scrollbar space-y-5 bg-background-light h-full pt-4">
            {/* Header */}
            <header className="sticky top-0 z-20 flex items-center justify-between py-5 bg-background-light/95 backdrop-blur-md transition-colors">
                <div className="flex flex-col">
                    <h1 className="text-2xl font-extrabold tracking-tight text-[#121516]">每日记录</h1>
                </div>
                <button className="group flex items-center justify-center w-10 h-10 rounded-full bg-white shadow-sm border border-transparent hover:border-primary/20 transition-all active:scale-95">
                    <Settings size={22} className="text-stone-600 group-hover:text-primary transition-colors" />
                </button>
            </header>

            {/* List */}
            <div className="space-y-6">
                {SAMPLE_DATA.map(entry => (
                    <DailyCard 
                        key={entry.id} 
                        entry={entry} 
                        onDetailClick={() => navigate(`/detail/${entry.id}`)}
                    />
                ))}
                
                {/* Spacer for scrolling past bottom nav */}
                <div className="h-16"></div>
            </div>
        </div>
    );
};