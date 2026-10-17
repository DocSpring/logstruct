import { LogField } from '@/generated/logstruct/enums';
import logStructs from '@/generated/logstruct/sorbet-log-structs.json';

interface StructEntry {
  name: string;
  simple_name: string;
  fields: Record<string, unknown>;
}

const STRUCTS = logStructs as Record<string, StructEntry>;

export interface LogFieldRow {
  /** The LogField constant, e.g. MailerClass */
  name: string;
  /** The JSON key, e.g. mailer */
  key: string;
  /** The built-in log types that write it, e.g. Log::ActiveJob::* or Log::Request */
  usedBy: string[];
}

/** A log type's name as the docs show it: LogStruct::Log::ActiveJob::Enqueue is Log::ActiveJob::Enqueue */
export function shortTypeName(fullName: string): string {
  return fullName.replace(/^LogStruct::/, '');
}

/** The source a log type belongs to: Log::ActiveJob for Log::ActiveJob::Enqueue, Log::Request for Log::Request */
export function typeCategory(fullName: string): string {
  const parts = shortTypeName(fullName).split('::');
  return parts.slice(0, 2).join('::');
}

/** The built-in log types (the BaseFields structs only hold fields that several types share) */
export function builtInLogTypes(): string[] {
  return Object.keys(STRUCTS)
    .filter((name) => STRUCTS[name].simple_name !== 'BaseFields')
    .sort();
}

/** A LogField's property name in the log types: MailerClass is mailer_class */
export function propertyName(logFieldName: string): string {
  return logFieldName
    .replace(/([a-z\d])([A-Z])/g, '$1_$2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
    .toLowerCase();
}

/** The log types that have a property, with Log::ActiveJob::* standing for every ActiveJob type */
function typesWithProperty(property: string): string[] {
  const types = builtInLogTypes();
  const using = types.filter((name) => property in STRUCTS[name].fields);
  if (using.length === 0) return [];
  if (using.length === types.length) return ['Every log type'];

  const byCategory = new Map<string, string[]>();
  for (const name of types) {
    const category = typeCategory(name);
    byCategory.set(category, [...(byCategory.get(category) ?? []), name]);
  }

  const labels: string[] = [];
  for (const [category, members] of byCategory) {
    const used = members.filter((name) => using.includes(name));
    if (used.length === 0) continue;
    if (used.length === members.length && members.length > 1) {
      labels.push(`${category}::*`);
    } else {
      labels.push(...used.map(shortTypeName));
    }
  }
  return labels;
}

/** Every LogField with its JSON key and the built-in log types that write it, sorted by key */
export function logFieldRows(): LogFieldRow[] {
  return Object.entries(LogField)
    .map(([name, key]) => ({ name, key, usedBy: typesWithProperty(propertyName(name)) }))
    .sort((a, b) => a.key.localeCompare(b.key));
}

/** The properties of the built-in log types that aren't LogFields (only additional_data) */
export function propertiesWithoutLogField(): string[] {
  const fieldProperties = new Set(Object.keys(LogField).map(propertyName));
  const properties = new Set(
    builtInLogTypes().flatMap((name) => Object.keys(STRUCTS[name].fields)),
  );
  return [...properties].filter((property) => !fieldProperties.has(property)).sort();
}
