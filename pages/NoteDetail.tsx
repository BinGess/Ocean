import React from 'react';
import { ArrowLeft, Sparkles, Eye, Heart, Sprout, Lightbulb, Pencil, Undo } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const NVC_CARDS = [
    {
        title: "观察 (Observation)",
        content: "盘子还没有被洗。",
        prefix: "也许是...",
        icon: Eye,
        colorClass: "text-primary",
        bgIcon: "bg-white",
        border: "border-primary/20",
        sideColor: "bg-primary/20"
    },
    {
        title: "感受 (Feeling)",
        content: "沮丧，不知所措",
        prefix: "也许是...",
        isTags: true,
        tags: ["沮丧", "不知所措"],
        icon: Heart,
        colorClass: "text-terracotta",
        bgIcon: "bg-white",
        border: "border-terracotta/40",
        sideColor: "bg-terracotta/40"
    },
    {
        title: "需求 (Need)",
        content: "支持，秩序，共识。",
        prefix: "也许是...",
        icon: Sprout,
        colorClass: "text-primary", // Using primary as per design which uses greenish for Sprout usually but design shows teal
        bgIcon: "bg-white",
        border: "border-terracotta/40",
        sideColor: "bg-terracotta/40"
    },
    {
        title: "行动建议 (Action)",
        content: "试着在双方都平静时，用‘我’字句表达感受，而不是指责。",
        prefix: "行动...",
        icon: Lightbulb,
        colorClass: "text-primary",
        bgIcon: "bg-white",
        border: "border-primary/20",
        sideColor: "bg-primary/20"
    }
];

export const NoteDetail: React.FC = () => {
    const navigate = useNavigate();

    return (
        <div className="flex items-center justify-center min-h-screen bg-[#e8e8e8] sm:p-4">
            <div className="relative flex h-full min-h-screen sm:min-h-0 sm:h-[850px] w-full max-w-[420px] flex-col bg-background-light sm:rounded-[32px] overflow-hidden shadow-2xl">
                
                {/* Header */}
                <header className="flex items-center justify-between px-5 pt-6 pb-2 bg-background-light z-20 sticky top-0">
                    <button 
                        onClick={() => navigate(-1)}
                        className="flex items-center justify-center w-10 h-10 -ml-2 text-gray-800 rounded-full hover:bg-black/5 transition-colors"
                    >
                        <ArrowLeft size={20} />
                    </button>
                    <h1 className="text-xs font-bold tracking-widest uppercase text-gray-400">10月24日 • 上午 9:41</h1>
                    <button 
                        onClick={() => navigate('/records')}
                        className="text-primary font-bold text-base px-2 py-1 rounded-lg hover:bg-primary/10 transition-colors"
                    >
                        完成
                    </button>
                </header>

                <main className="flex-1 px-5 pb-8 overflow-y-auto no-scrollbar flex flex-col gap-6 relative">
                    
                    {/* Transcript Area */}
                    <section className="flex flex-col gap-2 pt-2">
                        <div className="relative group">
                            <textarea 
                                className="w-full min-h-[140px] bg-surface-light rounded-2xl p-5 text-[17px] leading-[1.6] text-text-main resize-none border-0 focus:ring-0 focus:bg-white placeholder-gray-400 selection:bg-terracotta/30 transition-all shadow-none group-hover:shadow-soft outline-none" 
                                id="transcript" 
                                placeholder="开始说话或输入..."
                                defaultValue="当他再次没洗碗时，我感到非常沮丧。感觉好像只有我一个人在乎保持房子整洁..."
                            />
                        </div>
                    </section>

                    {/* Insights Section */}
                    <section className="flex flex-col gap-5 pb-6 pt-2">
                        <div className="px-1 flex items-center gap-2">
                            <Sparkles size={18} className="text-terracotta" />
                            <p className="text-xs font-medium text-terracotta">洞察</p>
                        </div>

                        {NVC_CARDS.map((card, idx) => (
                            <article key={idx} className="bg-surface-light rounded-2xl p-4 pr-3 shadow-soft border border-white/50 transition-all relative overflow-hidden group hover:bg-white">
                                <div className={`absolute top-0 left-0 w-1 h-full ${card.sideColor}`}></div>
                                <div className="flex gap-4">
                                    <div className="flex flex-col items-center gap-2 pt-1">
                                        <div className={`w-8 h-8 rounded-full ${card.bgIcon} flex items-center justify-center ${card.colorClass} shadow-sm ring-1 ring-black/5`}>
                                            <card.icon size={18} />
                                        </div>
                                    </div>
                                    <div className="flex-1 flex flex-col gap-3">
                                        <div className="flex justify-between items-start">
                                            <h3 className={`font-bold ${card.colorClass === 'text-terracotta' ? 'text-terracotta' : 'text-primary'} text-sm`}>{card.title}</h3>
                                        </div>
                                        <div className="text-[15px] leading-relaxed text-text-main">
                                            <span className="italic text-gray-400 text-sm font-light mr-1">{card.prefix}</span>
                                            {card.isTags ? (
                                                <span className="inline-flex flex-wrap gap-1">
                                                    {card.tags?.map(tag => (
                                                        <span key={tag} className="bg-terracotta/10 text-terracotta px-1.5 rounded text-sm font-semibold">{tag}</span>
                                                    ))}
                                                </span>
                                            ) : (
                                                card.content
                                            )}
                                        </div>
                                        <div className="flex gap-2 mt-1 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                                            <button className="flex items-center gap-1.5 px-3 py-1.5 bg-white rounded-lg text-xs font-bold text-primary shadow-sm hover:bg-primary hover:text-white transition-colors border border-transparent">
                                                确认
                                            </button>
                                            <button className="flex items-center justify-center w-8 h-8 rounded-full text-gray-400 hover:text-primary hover:bg-white transition-colors">
                                                <Pencil size={16} />
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </article>
                        ))}
                    </section>

                    <footer className="mt-2 flex justify-center pb-8 opacity-60 hover:opacity-100 transition-opacity">
                        <button className="flex items-center gap-2 px-4 py-2 rounded-full text-xs font-semibold text-gray-400 hover:text-gray-600 hover:bg-black/5 transition-all">
                            <Undo size={18} />
                            恢复为仅录音
                        </button>
                    </footer>
                </main>
                
                {/* Bottom Fade */}
                <div className="absolute bottom-0 left-0 w-full h-8 bg-gradient-to-t from-background-light to-transparent pointer-events-none"></div>
            </div>
        </div>
    );
};