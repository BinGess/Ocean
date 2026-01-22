import { Mood } from './types';

export const MOOD_COLORS: Record<Mood, { bg: string; text: string; dot: string }> = {
    [Mood.HighPleasure]: { bg: "bg-sage/20", text: "text-[#4a5746]", dot: "bg-sage" },
    [Mood.LowAnxiety]: { bg: "bg-terracotta/20", text: "text-[#5c3a31]", dot: "bg-terracotta" },
    [Mood.Calm]: { bg: "bg-stone-100", text: "text-stone-600", dot: "bg-stone-400" },
    [Mood.Focus]: { bg: "bg-primary/10", text: "text-primary", dot: "bg-primary" },
    [Mood.Uncertainty]: { bg: "bg-gray-100", text: "text-gray-600", dot: "bg-gray-400" },
};

export const MOOD_LABELS: Record<Mood, string> = {
    [Mood.HighPleasure]: "愉悦高涨",
    [Mood.LowAnxiety]: "轻微焦虑",
    [Mood.Calm]: "平静",
    [Mood.Focus]: "专注",
    [Mood.Uncertainty]: "不确定"
};