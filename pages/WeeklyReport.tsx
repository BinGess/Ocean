import React from 'react';
import { ArrowLeft, Share, BarChart2, Quote, Lightbulb, FlaskConical } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { BarChart, Bar, ResponsiveContainer, Cell } from 'recharts';

const CHART_DATA = [
    { day: '一', val: 30, color: '#E0EBE2' },
    { day: '二', val: 50, color: '#D8E1E8' },
    { day: '三', val: 80, color: '#48697a' }, // Highlight
    { day: '四', val: 40, color: '#EEDDD8' },
    { day: '五', val: 35, color: '#EEDDD8' },
    { day: '六', val: 45, color: '#e5e7eb' },
    { day: '日', val: 60, color: '#e5e7eb' },
];

export const WeeklyReport: React.FC = () => {
    const navigate = useNavigate();

    return (
        <div className="flex-1 px-5 pb-28 flex flex-col gap-5 pt-2 bg-background-light h-full overflow-y-auto no-scrollbar">
            {/* Header */}
            <header className="sticky top-0 z-50 px-1 pt-4 pb-2 bg-background-light/95 backdrop-blur-md">
                <div className="grid grid-cols-3 items-center">
                    <button 
                        onClick={() => navigate(-1)}
                        className="justify-self-start flex items-center justify-center p-2 -ml-2 rounded-full hover:bg-black/5 transition-colors"
                    >
                        <ArrowLeft size={24} className="text-text-main" />
                    </button>
                    <div className="flex flex-col items-center justify-center text-center">
                        <h1 className="text-lg font-bold text-text-main tracking-tight">10月16日 - 10月23日</h1>
                        <span className="text-[11px] font-medium text-text-light mt-0.5">周报洞察</span>
                    </div>
                    <button className="justify-self-end flex items-center justify-center p-2 -mr-2 rounded-full hover:bg-black/5 transition-colors">
                        <Share size={24} className="text-text-main" />
                    </button>
                </div>
            </header>

            {/* Emotional Overview Card */}
            <section className="bg-white rounded-[24px] p-7 shadow-card transition-all duration-300 hover:shadow-soft border border-white/50">
                <div className="flex items-center gap-3 mb-6">
                    <div className="h-8 w-8 rounded-lg bg-gray-100 flex items-center justify-center text-primary/70">
                        <BarChart2 size={18} fill="currentColor" />
                    </div>
                    <h2 className="text-base font-bold text-text-main tracking-wide">情绪概览</h2>
                </div>
                
                <div className="space-y-6">
                    <p className="text-[15px] leading-7 text-text-main/90 font-normal tracking-wide text-justify">
                        本周你的情绪变化显著。周一你感到<span className="text-terracotta font-medium">专注且坚定</span>，而到了周三出现了一些<span className="text-terracotta font-medium">不确定感</span>。临近周五，一种释然感成为了主导。
                    </p>
                    
                    {/* Tiny Chart */}
                    <div className="h-16 w-full pt-4">
                         <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={CHART_DATA}>
                                <Bar dataKey="val" radius={[2, 2, 2, 2]}>
                                    {CHART_DATA.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={entry.color} />
                                    ))}
                                </Bar>
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>
            </section>

            {/* Frequent Contexts */}
            <section>
                <div className="flex items-center justify-between px-1 mb-3">
                    <h3 className="text-xs font-bold text-text-light">高频场景</h3>
                    <Quote size={18} className="text-gray-300" />
                </div>
                <div className="space-y-3">
                    <div className="relative pl-3">
                        <div className="absolute left-0 top-3 h-full w-0.5 bg-[#D4BDA5] rounded-full opacity-60"></div>
                        <div className="bg-white p-5 rounded-[20px] shadow-card border border-white/50">
                            <p className="text-[14px] italic text-text-main/80 mb-3 leading-relaxed tracking-wide">"深度工作时不断的打断让我感到非常紧张..."</p>
                            <span className="text-xs font-medium text-[#D4BDA5]">周二 • 14:00</span>
                        </div>
                    </div>
                    <div className="relative pl-3">
                        <div className="absolute left-0 top-3 h-full w-0.5 bg-[#D4BDA5] rounded-full opacity-60"></div>
                        <div className="bg-white p-5 rounded-[20px] shadow-card border border-white/50">
                            <p className="text-[14px] italic text-text-main/80 mb-3 leading-relaxed tracking-wide">"因为没写完报告感到沮丧。我只想要一些安静的时间。"</p>
                            <span className="text-xs font-medium text-[#D4BDA5]">周四 • 10:00</span>
                        </div>
                    </div>
                </div>
            </section>

            {/* Pattern Hypothesis */}
            <section className="mt-2">
                <div className="bg-[#F2F1EF] rounded-[24px] overflow-hidden shadow-none border border-white/40">
                    <div className="px-6 pt-5 pb-3 flex items-center gap-2.5">
                        <Lightbulb size={20} className="text-text-main/60" fill="currentColor" />
                        <h3 className="text-sm font-bold text-text-main/80 tracking-wide">模式假设</h3>
                    </div>
                    <div className="px-7 pb-8 pt-1 bg-[#F6F5F3]">
                        <p className="text-[16px] font-medium text-text-main leading-8 tracking-wide text-justify opacity-90">
                            看起来<span className="text-[#9C7A70] bg-[#EEDDD8]/40 px-1.5 py-0.5 rounded-md mx-0.5">工作中的打断</span>触发了你对<span className="text-[#5b7c99] bg-[#D8E1E8]/50 px-1.5 py-0.5 rounded-md mx-0.5">胜任感与心流</span>的强烈需求。
                        </p>
                    </div>
                </div>
            </section>

            {/* Micro Experiment */}
            <section className="mt-2 pb-8">
                <div className="relative overflow-hidden rounded-[24px] bg-[#EEF2F5] p-1 shadow-inner border border-white/50">
                    <div className="relative flex flex-col items-start gap-3 rounded-[20px] p-6">
                        <div className="flex items-center gap-2 rounded-full bg-slate-200/50 px-3 py-1 mb-1">
                            <FlaskConical size={14} className="text-primary fill-primary" />
                            <span className="text-xs font-bold text-primary">微实验</span>
                        </div>
                        <h3 className="text-xl font-bold text-text-main mt-1">守护心流</h3>
                        <p className="text-[15px] text-text-main/80 leading-relaxed font-normal">
                            下次开始深度工作时，尝试在桌上放一个显眼的<strong>“请勿打扰”信号</strong>，坚持30分钟。
                        </p>
                    </div>
                </div>
            </section>
        </div>
    );
};