import React from 'react';
import { User, Sparkles, Mic, Disc } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export const Home: React.FC = () => {
    const navigate = useNavigate();

    return (
        <div className="flex-1 flex flex-col w-full relative overflow-hidden bg-background-light h-full">
            {/* Header */}
            <header className="flex items-center justify-between px-6 pt-12 pb-2 w-full z-20 flex-none">
                <div className="flex flex-col gap-1">
                    <span className="text-xs font-medium text-gray-400 tracking-wide">10月24日 周三</span>
                    <h2 className="text-3xl font-bold leading-tight tracking-tight text-primary">
                        早上好
                    </h2>
                </div>
                <button 
                    className="w-10 h-10 flex items-center justify-center rounded-full bg-white shadow-sm border border-gray-100 text-primary transition-transform active:scale-95 hover:bg-gray-50"
                    onClick={() => {/* TODO: Open Profile */}}
                >
                    <User size={20} />
                </button>
            </header>

            {/* Background Ambient Light */}
            <div aria-hidden="true" className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
                <div className="absolute top-[15%] left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-gradient-to-b from-[#E6EBF0]/60 to-transparent rounded-full blur-3xl opacity-60"></div>
            </div>

            {/* Center Text */}
            <section className="flex-1 flex flex-col justify-center items-center px-8 z-10 pb-32">
                <div className="flex flex-col items-center gap-6 text-center select-none">
                    <p className="text-base text-primary/30 font-medium transform scale-90 blur-[0.5px] transition-all duration-700">
                        接纳所有情绪
                    </p>
                    <p className="text-lg text-primary/50 font-medium transform scale-95 transition-all duration-700">
                        让感受自由流动
                    </p>
                    <p className="text-2xl text-primary/70 font-medium transition-all duration-700">
                        允许一切发生
                    </p>
                    <p className="text-3xl md:text-4xl text-primary font-bold tracking-tight transition-all duration-700 drop-shadow-sm mt-3 animate-float">
                        先看见，再思考
                    </p>
                </div>
            </section>

            {/* Bottom Actions */}
            <section className="absolute bottom-0 left-0 w-full flex flex-col items-center justify-end pb-24 z-20 bg-gradient-to-t from-background-light via-background-light/90 to-transparent pt-16">
                <button 
                    onClick={() => navigate('/detail/new')}
                    className="mb-8 group flex items-center gap-2.5 pl-3 pr-4 py-2.5 rounded-full bg-white border border-gray-200 shadow-sm hover:shadow-md hover:border-primary/30 transition-all cursor-pointer active:scale-95"
                >
                    <div className="relative w-5 h-5 flex items-center justify-center">
                        <Sparkles size={18} className="text-yellow-500 fill-yellow-500 animate-pulse-slow" />
                    </div>
                    <span className="text-sm font-semibold text-primary">开启洞察</span>
                    <div className="w-8 h-4 bg-gray-200 rounded-full relative ml-1 transition-colors group-active:bg-primary/20 group-hover:bg-gray-300">
                        <div className="absolute left-0.5 top-0.5 w-3 h-3 bg-white rounded-full shadow-sm transition-transform"></div>
                    </div>
                </button>
                
                <p className="mb-6 text-sm font-semibold text-gray-400 tracking-[0.2em] uppercase">
                    长按录音
                </p>
                
                {/* Recording Button */}
                <div 
                    className="relative group cursor-pointer select-none touch-none" 
                    role="button"
                    // TODO: Bind recording events
                    onMouseDown={() => console.log('Start recording')}
                    onMouseUp={() => console.log('Stop recording')}
                    onTouchStart={() => console.log('Start recording')}
                    onTouchEnd={() => console.log('Stop recording')}
                >
                    <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-32 h-32 bg-primary/5 rounded-full animate-pulse-slow"></div>
                    <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-24 h-24 bg-primary/10 rounded-full animate-pulse"></div>
                    <div className="relative w-20 h-20 bg-primary rounded-full shadow-xl shadow-primary/30 flex items-center justify-center transition-all duration-200 group-active:scale-95 group-active:shadow-inner ring-4 ring-white">
                        <Mic size={36} className="text-white fill-white" />
                    </div>
                </div>
            </section>
        </div>
    );
};