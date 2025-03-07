'use client';

import React from 'react';
import { Card } from './ui/card';
import {
  Chart,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
  CustomTooltip,
} from './ui/recharts';
import { LogGenerator } from '@/lib/log-generation/log-generator';

// Refined color palette with blues, purples - brightened dark colors
const chartColors = {
  darkBlue: {
    area: '#1c357a', // 10% brighter than original
    line: '#3373fa', // 10% brighter than original
  },
  lightBlue: {
    area: '#2d496b',
    line: '#60a8fa',
  },
  mediumBlue: {
    area: '#23439f', // 10% brighter
    line: '#4b92ff', // 10% brighter
  },
  lightestBlue: {
    area: '#2b4667',
    line: '#93c5fd',
  },
  purple: {
    area: '#372a5c', // 10% brighter
    line: '#9b6cff', // 10% brighter
  },
  yellow: {
    area: '#4c2507', // 10% brighter
    line: '#fabd18', // 10% brighter
  },
};

// Generate some sample data for our charts
const generateChartData = () => {
  const generator = new LogGenerator(12345); // Use consistent seed for demos

  // Data for request duration
  const generateRequestDurationData = () => {
    const days = 14;
    const data: Array<Record<string, number | string>> = [];

    for (let day = 0; day < days; day++) {
      const entry: Record<string, number | string> = {
        date: new Date(
          Date.now() - (days - day) * 24 * 60 * 60 * 1000,
        ).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      };

      // Base avg value between 80-150ms
      const avgValue = generator.randomInt(80, 150);

      // P95 is typically 1.5-2x the average
      const p95Value = Math.round(
        avgValue * (1.5 + generator.randomFloat(0, 0.5)),
      );

      // P99 is typically 2-3x the average
      const p99Value = Math.round(avgValue * (2 + generator.randomFloat(0, 1)));

      entry['avg'] = avgValue;
      entry['p95'] = p95Value;
      entry['p99'] = p99Value;

      data.push(entry);
    }

    return data;
  };

  // Data for mailer events chart - simplified to just show Delivery and Error
  const generateMailerData = () => {
    const days = 14;

    const data: Array<Record<string, number | string>> = [];

    // Create specific days for error spikes
    const errorSpikes = [4, 11]; // Days with error spikes

    for (let day = 0; day < days; day++) {
      const entry: Record<string, number | string> = {
        date: new Date(
          Date.now() - (days - day) * 24 * 60 * 60 * 1000,
        ).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      };

      // Total deliveries (combine all mailers)
      entry['delivery'] = generator.randomInt(500, 1200);

      // Base error rate - still low on most days but more noticeable
      if (generator.randomInt(0, 100) < 70) {
        entry['error'] = generator.randomInt(5, 15);
      } else {
        entry['error'] = generator.randomInt(15, 25);
      }

      // Add medium spikes randomly
      if (day === 7 || day === 2) {
        entry['error'] = generator.randomInt(30, 50);
      }

      // Add dramatic spikes on specific days
      if (errorSpikes.includes(day)) {
        entry['error'] = generator.randomInt(75, 120);
      }

      data.push(entry);
    }

    return data;
  };

  // Data for Sidekiq job processing
  const generateSidekiqData = () => {
    const queues = ['default', 'critical', 'mailers', 'low'];
    const days = 7;

    const data: Array<Record<string, number | string>> = [];

    for (let day = 0; day < days; day++) {
      const entry: Record<string, number | string> = {
        date: new Date(
          Date.now() - (days - day) * 24 * 60 * 60 * 1000,
        ).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      };

      for (const queue of queues) {
        let base = 100;
        if (queue === 'critical') base = 50;
        if (queue === 'mailers') base = 200;
        if (queue === 'low') base = 30;

        entry[queue] = generator.randomInt(base * 0.7, base * 1.3);
      }

      data.push(entry);
    }

    return data;
  };

  // Data for rack attack rate limiting - broken down by category
  const generateRackAttackData = () => {
    const days = 14;
    const data: Array<Record<string, number | string>> = [];

    // Days with pentester spikes
    const pentesterSpikes = [4, 11]; // Specific days with pentester activities

    // Days with API limit spikes
    const apiSpikes = [7];

    // Days with signup spikes
    const signupSpikes = [2, 9];

    for (let day = 0; day < days; day++) {
      const entry: Record<string, number | string> = {
        date: new Date(
          Date.now() - (days - day) * 24 * 60 * 60 * 1000,
        ).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      };

      // Base low levels for each category
      entry['api'] =
        generator.randomInt(0, 100) < 70 ? 0 : generator.randomInt(1, 10);
      entry['signup'] =
        generator.randomInt(0, 100) < 80 ? 0 : generator.randomInt(1, 5);
      entry['pentesters'] =
        generator.randomInt(0, 100) < 90 ? 0 : generator.randomInt(1, 3);

      // Add spikes on specific days
      if (apiSpikes.includes(day)) {
        entry['api'] = generator.randomInt(30, 70);
      }

      if (signupSpikes.includes(day)) {
        entry['signup'] = generator.randomInt(15, 25);
      }

      if (pentesterSpikes.includes(day)) {
        entry['pentesters'] = generator.randomInt(80, 150);
      }

      data.push(entry);
    }

    return data;
  };

  // Data for security events with mostly zeros and occasional spikes
  const generateSecurityData = () => {
    // Security event types
    const days = 14;

    const data: Array<Record<string, number | string>> = [];

    // Create a few spike days (rarely occurring security events)
    const blockedHostSpikes = [3, 10]; // Days with blocked host spikes
    const ipSpoofSpikes = [7]; // Days with IP spoof spikes
    const csrfSpikes = [5, 12]; // Days with CSRF violation spikes

    for (let day = 0; day < days; day++) {
      const entry: Record<string, number | string> = {
        date: new Date(
          Date.now() - (days - day) * 24 * 60 * 60 * 1000,
        ).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      };

      // Default to 0 for most days, with occasional small amounts (1-2)
      entry['blocked_host'] =
        generator.randomInt(0, 100) < 80 ? 0 : generator.randomInt(1, 2);
      entry['ip_spoof'] = generator.randomInt(0, 100) < 90 ? 0 : 1;
      entry['csrf_violation'] = generator.randomInt(0, 100) < 95 ? 0 : 1;

      // Add spikes on specific days
      if (blockedHostSpikes.includes(day)) {
        entry['blocked_host'] = generator.randomInt(8, 15);
      }

      if (ipSpoofSpikes.includes(day)) {
        entry['ip_spoof'] = generator.randomInt(4, 8);
      }

      if (csrfSpikes.includes(day)) {
        entry['csrf_violation'] = generator.randomInt(3, 6);
      }

      data.push(entry);
    }

    return data;
  };

  // Data for error rates - mostly low with occasional minor errors
  const generateErrorData = () => {
    // Define error categories monitored
    const days = 14;

    const data: Array<Record<string, number | string>> = [];

    // Create a spike pattern for specific days
    const error500Spikes = [4, 11]; // Days with server error spikes
    const error422Spikes = [2, 8]; // Days with validation error spikes
    const dbErrorSpikes = [6]; // Days with database error spikes
    const timeoutSpikes = [9]; // Days with timeout spikes

    for (let day = 0; day < days; day++) {
      const entry: Record<string, number | string> = {
        date: new Date(
          Date.now() - (days - day) * 24 * 60 * 60 * 1000,
        ).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      };

      // Default to low error rates (0-2)
      entry['500_errors'] =
        generator.randomInt(0, 100) < 80 ? 0 : generator.randomInt(1, 2);
      entry['422_errors'] = generator.randomInt(1, 5); // Validation errors are more common
      entry['db_errors'] =
        generator.randomInt(0, 100) < 85 ? 0 : generator.randomInt(1, 2);
      entry['timeouts'] = generator.randomInt(0, 100) < 90 ? 0 : 1;

      // Add spikes on specific days
      if (error500Spikes.includes(day)) {
        entry['500_errors'] = generator.randomInt(4, 8);
      }

      if (error422Spikes.includes(day)) {
        entry['422_errors'] = generator.randomInt(12, 18);
      }

      if (dbErrorSpikes.includes(day)) {
        entry['db_errors'] = generator.randomInt(3, 6);
      }

      if (timeoutSpikes.includes(day)) {
        entry['timeouts'] = generator.randomInt(5, 10);
      }

      data.push(entry);
    }

    return data;
  };

  return {
    requestDurationData: generateRequestDurationData(),
    mailerData: generateMailerData(),
    sidekiqData: generateSidekiqData(),
    rackAttackData: generateRackAttackData(),
    securityData: generateSecurityData(),
    errorData: generateErrorData(),
  };
};

const DashboardExamples = () => {
  // Generate chart data
  const chartData = generateChartData();

  return (
    <div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {/* Rails Request Duration Chart */}
        <Card className="p-5 shadow-sm">
          <h3 className="text-lg font-semibold mb-2">Request Duration</h3>
          <div className="h-64">
            <Chart aspectRatio={1.6}>
              <AreaChart data={chartData.requestDurationData}>
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                {/* <Area
                  type="monotone"
                  dataKey="p99"
                  name="p99"
                  stroke={chartColors.purple.line}
                  fill={chartColors.purple.area}
                  fillOpacity={0.5}
                  dot={false}
                /> */}
                <Area
                  type="monotone"
                  dataKey="p95"
                  name="p95"
                  stroke={chartColors.darkBlue.line}
                  fill={chartColors.darkBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="avg"
                  name="avg"
                  stroke={chartColors.lightBlue.line}
                  fill={chartColors.lightBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
              </AreaChart>
            </Chart>
          </div>
        </Card>

        {/* Sidekiq Job Chart */}
        <Card className="p-5 shadow-sm">
          <h3 className="text-lg font-semibold mb-2">Sidekiq Jobs</h3>
          <div className="h-64">
            <Chart aspectRatio={1.6}>
              <AreaChart data={chartData.sidekiqData}>
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                <Area
                  type="monotone"
                  dataKey="default"
                  name="Default"
                  stroke={chartColors.darkBlue.line}
                  fill={chartColors.darkBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="critical"
                  name="Critical"
                  stroke={chartColors.purple.line}
                  fill={chartColors.purple.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="low"
                  name="Low"
                  stroke={chartColors.lightBlue.line}
                  fill={chartColors.lightBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
              </AreaChart>
            </Chart>
          </div>
        </Card>

        {/* Mailer Events Chart */}
        {/* <Card className="p-5 shadow-sm hidden sm:block">
          <h3 className="text-lg font-semibold mb-2">Mailer Events</h3>
          <div className="h-64">
            <Chart aspectRatio={1.6}>
              <AreaChart data={chartData.mailerData}>
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                <Area
                  type="monotone"
                  dataKey="delivery"
                  name="Delivery"
                  stroke={chartColors.lightBlue.line}
                  fill={chartColors.lightBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="error"
                  name="Error"
                  stroke={chartColors.purple.line}
                  fill={chartColors.purple.area}
                  fillOpacity={0.5}
                  dot={false}
                />
              </AreaChart>
            </Chart>
          </div>
        </Card> */}

        {/* Security Events Chart */}
        {/* <Card className="p-5 shadow-sm hidden sm:block">
          <h3 className="text-lg font-semibold mb-2">Security Events</h3>
          <div className="h-64">
            <Chart aspectRatio={1.6}>
              <AreaChart data={chartData.securityData}>
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                <Area
                  type="monotone"
                  dataKey="blocked_host"
                  name="Blocked Hosts"
                  stroke={chartColors.purple.line}
                  fill={chartColors.purple.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="ip_spoof"
                  name="IP Spoofing"
                  stroke={chartColors.darkBlue.line}
                  fill={chartColors.darkBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="csrf_violation"
                  name="CSRF Violations"
                  stroke={chartColors.lightBlue.line}
                  fill={chartColors.lightBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
              </AreaChart>
            </Chart>
          </div>
        </Card> */}

        {/* Rack Attack Rate Limiting */}
        <Card className="p-5 shadow-sm hidden lg:block">
          <h3 className="text-lg font-semibold mb-2">Rate Limiting</h3>
          <div className="h-64">
            <Chart aspectRatio={1.6}>
              <AreaChart data={chartData.rackAttackData}>
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                {/* <Area
                  type="monotone"
                  dataKey="pentesters"
                  name="Pentesters"
                  stroke={chartColors.purple.line}
                  fill={chartColors.purple.area}
                  fillOpacity={0.5}
                  dot={false}
                /> */}
                <Area
                  type="monotone"
                  dataKey="signup"
                  name="Sign Ups"
                  stroke={chartColors.darkBlue.line}
                  fill={chartColors.darkBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="api"
                  name="API Requests"
                  stroke={chartColors.lightBlue.line}
                  fill={chartColors.lightBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
              </AreaChart>
            </Chart>
          </div>
        </Card>

        {/* Error Rates by Type */}
        {/* <Card className="p-5 shadow-sm hidden lg:block">
          <h3 className="text-lg font-semibold mb-2">Error Rates</h3>
          <div className="h-64">
            <Chart aspectRatio={1.6}>
              <AreaChart data={chartData.errorData}>
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                <Area
                  type="monotone"
                  dataKey="500_errors"
                  name="500 Errors"
                  stroke={chartColors.purple.line}
                  fill={chartColors.purple.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="422_errors"
                  name="422 Errors"
                  stroke={chartColors.darkBlue.line}
                  fill={chartColors.darkBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
                <Area
                  type="monotone"
                  dataKey="timeouts"
                  name="Timeouts"
                  stroke={chartColors.lightBlue.line}
                  fill={chartColors.lightBlue.area}
                  fillOpacity={0.5}
                  dot={false}
                />
              </AreaChart>
            </Chart>
          </div>
        </Card> */}
      </div>
    </div>
  );
};

export default DashboardExamples;
