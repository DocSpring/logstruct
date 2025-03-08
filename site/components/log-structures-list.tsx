import { getLogStructureDescription } from '@/lib/log-structure-descriptions';
import { cache } from 'react';

// Interface for the structure in the log structs JSON file
interface LogStructsData {
  [key: string]: {
    name: string;
    fields: Record<string, unknown>;
  };
}

// Function to get log structs data from JSON file with caching
const getLogStructsData = cache(async (): Promise<LogStructsData> => {
  try {
    // Use dynamic import to load the JSON file
    const data = await import('@/lib/log-generation/sorbet-log-structs.json');
    return data.default as LogStructsData;
  } catch (error) {
    console.error('Error loading log structures data:', error);
    return {};
  }
});

/**
 * Component that displays a bullet point list of LogStruct log structures
 * with their descriptions
 */
export async function LogStructuresList() {
  // Get the log structs data
  const structsData = await getLogStructsData();

  // Extract struct names (sorted alphabetically)
  const structEntries = Object.entries(structsData).sort(([, a], [, b]) =>
    a.name.localeCompare(b.name),
  );

  return (
    <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
      {structEntries.map(([fullName, { name }]) => (
        <li key={fullName}>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            Log::{name}
          </code>{' '}
          - {getLogStructureDescription(name)}
        </li>
      ))}
    </ul>
  );
}
