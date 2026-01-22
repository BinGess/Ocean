import React, { useState } from 'react';
import { MoreHorizontal, Mic, AlignLeft, ChevronDown } from 'lucide-react';
import { JournalEntry } from '../types';
import { MOOD_COLORS, MOOD_LABELS } from '../constants';

interface DailyCardProps {
    entry: JournalEntry;
    onDetailClick: () => void;
}

export const DailyCard: React.FC<DailyCardProps> = ({ entry, onDetailClick }) => {
    const [isOpen, setIsOpen] = useState(false);

    return (
        <article className="relative flex flex-col w-full bg-surface-light rounded-2xl shadow-soft p-5 border border-stone-100 transition-transform duration-300 active:scale-[0.99]">
            {/* Header */}
            <div className="flex items-start justify-between mb-4">
                <div className="flex flex-col">
                    <h2 className="text-xl font-bold text-stone-800">{entry.date} {entry.dayOfWeek}</h2>
                    {entry.isYesterday && <span className="text-xs text-stone-400 font-medium mt-0.5">昨天</span>}
                </div>
                <button 
                    className="text-stone-400 hover:text-stone-600 p-1"
                    onClick={() => {/* TODO: Open context menu */}}
                >
                    <MoreHorizontal size={20} />
                </button>
            </div>

            {/* Tags */}
            <div className="flex flex-wrap gap-2 mb-5">
                {entry.moods.map(mood => {
                    const style = MOOD_COLORS[mood];
                    return (
                        <div key={mood} className={`flex items-center px-3 py-1.5 rounded-lg border border-transparent ${style.bg}`}>
                            <span className={`w-1.5 h-1.5 rounded-full mr-2 ${style.dot}`}></span>
                            <span className={`text-xs font-bold tracking-wide ${style.text}`}>{MOOD_LABELS[mood]}</span>
                        </div>
                    );
                })}
            </div>

            {/* Summary Content */}
            {entry.summary ? (
                <div 
                    className="relative group cursor-pointer"
                    onClick={onDetailClick}
                >
                    <div className="absolute left-0 top-0 bottom-0 w-1 bg-primary/20 rounded-full group-hover:bg-primary transition-colors"></div>
                    <p className="pl-4 text-sm font-medium leading-relaxed text-stone-600 line-clamp-3 text-justify">
                        {entry.summary}
                    </p>
                </div>
            ) : (
                <button 
                    onClick={onDetailClick}
                    className="w-full flex items-center justify-center gap-2 py-8 rounded-xl border-2 border-dashed border-stone-200 text-stone-400 hover:border-primary/50 hover:text-primary hover:bg-primary/5 transition-all group"
                >
                    <div className="p-2 rounded-full bg-stone-50 group-hover:bg-primary/10 transition-colors">
                        <AlignLeft size={20} className="group-hover:scale-110 transition-transform" />
                    </div>
                    <span className="text-sm font-semibold">撰写日记</span>
                </button>
            )}

            {/* Quick Notes Accordion */}
            {entry.quickNotes.length > 0 && (
                <>
                    <div className="h-px w-full bg-stone-100 my-5"></div>
                    <div className="group/accordion">
                        <button 
                            onClick={() => setIsOpen(!isOpen)}
                            className="w-full flex cursor-pointer items-center justify-between select-none p-1 -m-1 rounded-lg hover:bg-stone-50 transition-colors"
                        >
                            <div className="flex items-center gap-3">
                                <div className="flex items-center justify-center w-8 h-8 rounded-full bg-primary/10 text-primary">
                                    <AlignLeft size={16} />
                                </div>
                                <div className="flex flex-col items-start">
                                    <span className="text-sm font-bold text-stone-700">{entry.quickNotes.length} 条速记</span>
                                    <span className="text-[10px] text-stone-400 font-medium uppercase tracking-wider">
                                        {entry.quickNotes.filter(n => n.type === 'audio').length} 语音 • {entry.quickNotes.filter(n => n.type === 'text').length} 文字
                                    </span>
                                </div>
                            </div>
                            <ChevronDown 
                                size={20} 
                                className={`text-stone-400 transition-transform duration-300 ${isOpen ? 'rotate-180' : ''}`} 
                            />
                        </button>
                        
                        {isOpen && (
                            <div className="pt-4 pl-11 space-y-3 animate-in slide-in-from-top-2 fade-in duration-200">
                                {entry.quickNotes.map((note) => (
                                    <div key={note.id} className="flex items-center justify-between group/item">
                                        <div className="flex items-center gap-3 overflow-hidden w-full">
                                            {note.type === 'audio' ? (
                                                <>
                                                    <Mic size={14} className="text-stone-400 flex-shrink-0" />
                                                    <div className="h-1 w-24 bg-stone-200 rounded-full overflow-hidden flex-shrink-0 relative">
                                                        <div className="h-full bg-primary" style={{ width: `${note.progress || 0}%` }}></div>
                                                    </div>
                                                    <span className="text-xs text-stone-500 font-mono">{note.duration}</span>
                                                </>
                                            ) : (
                                                <>
                                                    <AlignLeft size={14} className="text-stone-400 flex-shrink-0 mt-0.5" />
                                                    <p className="text-xs text-stone-600 italic truncate">"{note.content}"</p>
                                                </>
                                            )}
                                        </div>
                                        <span className="text-[10px] text-stone-400 whitespace-nowrap ml-2">{note.timestamp}</span>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </>
            )}
        </article>
    );
};