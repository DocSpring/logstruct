import {
  getEnumDescription,
  getEnumValueDescription,
} from '@/lib/enum-descriptions';
import { cache } from 'react';
import { HeadingWithAnchor } from './heading-with-anchor';

// Interface for the enum data in the JSON file
interface EnumData {
  [key: string]: Array<{
    name: string;
    value: string;
  }>;
}

// Function to get enum data from JSON file with caching
const getEnumsData = cache(async (): Promise<EnumData> => {
  try {
    // Use dynamic import to load the JSON file
    const data = await import('@/lib/log-generation/sorbet-enums.json');
    return data.default as EnumData;
  } catch (error) {
    console.error('Error loading enums data:', error);
    return {};
  }
});

/**
 * Component that displays a hierarchical bullet point list of LogStruct enums
 * with their descriptions and values
 */
export async function EnumsList() {
  // Get the enums data
  const enumsData = await getEnumsData();

  // Get enum names we want to display (in a specific order)
  const enumOrder = [
    'LogStruct::LogLevel',
    'LogStruct::Source',
    'LogStruct::LogEvent',
    'LogStruct::ErrorHandlingMode',
  ];

  // Filter and sort enums
  const sortedEnums = Object.keys(enumsData)
    .filter((enumName) => enumOrder.includes(enumName))
    .sort((a, b) => enumOrder.indexOf(a) - enumOrder.indexOf(b));

  return (
    <div className="space-y-6">
      {sortedEnums.map((enumName) => {
        const values = enumsData[enumName];
        // Get short name (last part after ::)
        const shortName = enumName.split('::').pop() || '';

        return (
          <div key={enumName} className="mb-4">
            <HeadingWithAnchor id={`enums-${shortName.toLowerCase()}`}>
              {shortName}
            </HeadingWithAnchor>
            <p className="text-neutral-600 dark:text-neutral-400 mb-2">
              {getEnumDescription(enumName)}
            </p>
            <ul className="list-disc list-inside space-y-1 text-neutral-600 dark:text-neutral-400 ml-4">
              {values.map(({ name, value }) => (
                <li key={`${enumName}-${name}`}>
                  <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
                    {shortName}::{name}
                  </code>{' '}
                  - {getEnumValueDescription(enumName, name)}
                </li>
              ))}
            </ul>
          </div>
        );
      })}
    </div>
  );
}
