'use client';

// shadcn-style chart components built on top of recharts
import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ComposedChart,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  TooltipProps,
  XAxis,
  YAxis,
} from 'recharts';
import { useTheme } from 'next-themes';

// Custom tooltip component for dark mode compatibility
const CustomTooltip = ({ active, payload, label }: TooltipProps<any, any>) => {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  if (active && payload && payload.length) {
    return (
      <div
        className={`${isDark ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'} 
                    border p-3 rounded-lg shadow-lg text-sm`}
      >
        <p
          className={`font-semibold mb-2 ${isDark ? 'text-white' : 'text-gray-800'}`}
        >
          {label}
        </p>
        {payload.map((entry, index) => (
          <div key={`item-${index}`} className="flex items-center py-1">
            <div
              className="w-3 h-3 rounded-full mr-2"
              style={{ backgroundColor: entry.color }}
            />
            <span
              className={`mr-2 ${isDark ? 'text-gray-300' : 'text-gray-600'}`}
            >
              {entry.name}:
            </span>
            <span
              className={`font-bold ${isDark ? 'text-white' : 'text-gray-800'}`}
            >
              {typeof entry.value === 'number'
                ? entry.value.toLocaleString()
                : entry.value}
            </span>
          </div>
        ))}
      </div>
    );
  }
  return null;
};

// Chart container with shadcn styling
const chartVariants = cva('w-full h-full', {
  variants: {
    variant: {
      default: '',
      condensed: 'p-2',
    },
  },
  defaultVariants: {
    variant: 'default',
  },
});

interface ChartProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof chartVariants> {
  aspectRatio?: number;
}

const Chart = React.forwardRef<HTMLDivElement, ChartProps>(
  ({ className, variant, aspectRatio = 2, children, ...props }, ref) => {
    const { theme } = useTheme();
    const isDark = theme === 'dark';

    // Modified children with enhanced styling
    const enhancedChildren = React.Children.map(children, (child) => {
      if (!React.isValidElement(child)) return child;

      return React.cloneElement(child as React.ReactElement, {
        ...child.props,
        // Apply better styling to chart elements
        style: {
          ...child.props.style,
          fontFamily: "'Inter', system-ui, sans-serif",
        },
        // Add consistent grid styling for all chart types
        children: React.Children.map(child.props.children, (grandChild) => {
          if (!React.isValidElement(grandChild)) return grandChild;

          // Add stylized CartesianGrid
          if (grandChild.type === CartesianGrid) {
            return React.cloneElement(grandChild as React.ReactElement, {
              ...grandChild.props,
              strokeDasharray: '3 3',
              stroke: isDark ? '#374151' : '#e5e7eb', // gray-700 or gray-200
              strokeOpacity: 0.8,
            });
          }

          // Style the XAxis
          if (grandChild.type === XAxis) {
            return React.cloneElement(grandChild as React.ReactElement, {
              ...grandChild.props,
              stroke: isDark ? '#6b7280' : '#9ca3af', // gray-500 or gray-400
              tick: { fill: isDark ? '#9ca3af' : '#4b5563', fontSize: 12 }, // gray-400 or gray-600
              tickLine: { stroke: isDark ? '#6b7280' : '#9ca3af' }, // gray-500 or gray-400
            });
          }

          // Style the YAxis
          if (grandChild.type === YAxis) {
            return React.cloneElement(grandChild as React.ReactElement, {
              ...grandChild.props,
              stroke: isDark ? '#6b7280' : '#9ca3af', // gray-500 or gray-400
              tick: { fill: isDark ? '#9ca3af' : '#4b5563', fontSize: 12 }, // gray-400 or gray-600
              tickLine: { stroke: isDark ? '#6b7280' : '#9ca3af' }, // gray-500 or gray-400
            });
          }

          // Style the Legend
          if (grandChild.type === Legend) {
            return React.cloneElement(grandChild as React.ReactElement, {
              ...grandChild.props,
              iconSize: 10,
              wrapperStyle: { fontSize: 12, paddingTop: 10 },
            });
          }

          return grandChild;
        }),
      });
    });

    return (
      <div
        ref={ref}
        className={cn(chartVariants({ variant }), className)}
        {...props}
      >
        <ResponsiveContainer width="100%" aspect={aspectRatio}>
          {enhancedChildren}
        </ResponsiveContainer>
      </div>
    );
  },
);
Chart.displayName = 'Chart';

// Color palette for chart elements
const COLORS = {
  primary: '#6366f1', // indigo-500
  secondary: '#ec4899', // pink-500
  success: '#10b981', // emerald-500
  warning: '#f59e0b', // amber-500
  danger: '#ef4444', // red-500
  info: '#06b6d4', // cyan-500
  muted: '#94a3b8', // slate-400
  accent1: '#8b5cf6', // violet-500
  accent2: '#0ea5e9', // sky-500
  accent3: '#f97316', // orange-500
};

// Re-export recharts components
export {
  Chart,
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ComposedChart,
  COLORS,
  CustomTooltip,
};
