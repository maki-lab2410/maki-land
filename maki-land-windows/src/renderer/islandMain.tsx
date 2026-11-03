import React from 'react';
import ReactDOM from 'react-dom/client';
import './styles.css';
import { IslandApp } from './IslandApp';

class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: string }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false, error: '' };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error: error.message || 'Render error' };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('[Maki Island ErrorBoundary]', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div
          style={{
            width: '100%',
            height: 34,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'flex-start',
          }}
        >
          <div
            style={{
              background: '#050507',
              color: '#fb923c',
              padding: '6px 16px',
              borderRadius: 99,
              fontSize: 10,
              fontWeight: 700,
              boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
              display: 'flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <span>🐾 Maki Island</span>
            <span style={{ fontSize: 8.5, opacity: 0.7 }}>({this.state.error.slice(0, 35)})</span>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <IslandApp />
    </ErrorBoundary>
  </React.StrictMode>
);
