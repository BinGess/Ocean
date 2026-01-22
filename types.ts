export enum Mood {
    HighPleasure = "HighPleasure",
    LowAnxiety = "LowAnxiety",
    Calm = "Calm",
    Focus = "Focus",
    Uncertainty = "Uncertainty"
}

export interface QuickNote {
    id: string;
    type: 'audio' | 'text';
    content?: string; // For text notes
    duration?: string; // For audio notes
    progress?: number; // 0-100 for audio
    timestamp: string;
}

export interface JournalEntry {
    id: string;
    date: string;
    dayOfWeek: string;
    isYesterday?: boolean;
    moods: Mood[];
    summary: string;
    quickNotes: QuickNote[];
}

export interface InsightBlock {
    type: 'fact' | 'feeling' | 'need' | 'action';
    title: string;
    content: string;
    tags?: string[];
    prefix?: string;
}
