import {
  getEnumDescription,
  getEnumValueDescription,
} from '@/lib/enum-descriptions';
import { cache } from 'react';
import { HeadingWithAnchor } from './heading-with-anchor';

interface EnumValue {
  name: string;
  serialized: string;
}

interface EnumEntry {
  name: string;
  simple_name: string;
  values: EnumValue[];
}

type EnumData = Record<string, EnumEntry>;

// Function to get enum data from JSON file with caching
const getEnumsData = cache(async (): Promise<EnumData> => {
  try {
    // Use dynamic import to load the JSON file
    const data = await import('@/generated/logstruct/sorbet-enums.json');
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
    'LogStruct::Level',
    'LogStruct::Source',
    'LogStruct::Event',
    'LogStruct::ErrorHandlingMode',
  ];

  // Filter and sort enums
  const sortedEnums = Object.keys(enumsData)
    .filter((enumName) => enumOrder.includes(enumName))
    .sort((a, b) => enumOrder.indexOf(a) - enumOrder.indexOf(b));

  return (
    <div className="space-y-6">
      {sortedEnums.map((enumName) => {
        const entry = enumsData[enumName];
        if (!entry) {
          return null;
        }
        const values = entry.values;
        // Get short name (last part after ::)
        const shortName = enumName.split('::').pop() || '';

        return (
          <div key={enumName} className="mb-4">
            <HeadingWithAnchor id={`enums-${shortName.toLowerCase()}`}>
              <code>{shortName}</code>
            </HeadingWithAnchor>
            <p className="text-neutral-600 dark:text-neutral-300 mb-2">
              {getEnumDescription(enumName)}
            </p>
            <ul className="list-disc list-inside space-y-1 text-neutral-600 dark:text-neutral-300 ml-4">
              {values.map(({ name }) => (
                <li key={`${enumName}-${name}`}>
                  <code className="py-0.5 text-neutral-800 dark:text-neutral-200 rounded">
                    {name}
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
