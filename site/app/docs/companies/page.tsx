import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { EditPageLink } from '@/components/edit-page-link';
interface ProductionCompany {
  name: string;
  url: string;
  logo: string;
  summary: string;
}

const productionCompanies: ProductionCompany[] = [
  {
    name: 'DocSpring',
    url: 'https://www.docspring.com',
    logo: 'https://docspring.com/logo.png',
    summary:
      'DocSpring is a PDF filling API that makes it easy to fill out PDF forms, ' +
      'convert HTML to PDFs, and collect legally-binding e-signatures. ' +
      'We built LogStruct to keep our production logs structured and secure.',
  },

  // {
  //   name: 'Your Company',
  //   url: 'https://www.example.com',
  //   logo: 'https://www.example.com/logo.svg',
  //   summary: '1-2 sentences about your company',
  // },
];

export default function CompaniesUsingLogStructPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="companies-using-logstruct-in-production" level={1}>
        Companies Using LogStruct
      </HeadingWithAnchor>

      <p className="text-neutral-600 dark:text-neutral-400">
        Does your team run LogStruct in production? Click the edit link below to
        add your company to the list.
      </p>

      <hr className="my-14" />

      <ul className="space-y-14 list-inside">
        {productionCompanies.map((company) => (
          <li key={company.name}>
            <a
              href={`${company.url}?utm_source=logstruct&utm_medium=referral`}
              target="_blank"
              rel="noopener noreferrer"
              className="font-semibold text-2xl hover:underline flex items-center space-x-2"
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={company.logo}
                alt={company.name}
                className="w-8 h-8 mr-4"
              />
              {company.name}
            </a>

            <div className="text-neutral-600 dark:text-neutral-400 pt-4">
              {company.summary}
            </div>
          </li>
        ))}
      </ul>

      <EditPageLink />
    </div>
  );
}
