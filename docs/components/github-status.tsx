'use client';

import { useState, useEffect } from 'react';
import { Github, Loader2 } from 'lucide-react';

type WorkflowStatus = {
  status: string;
  conclusion: string | null;
  url: string | null;
  loading: boolean;
};

export function GitHubStatus() {
  const [workflowStatus, setWorkflowStatus] = useState<WorkflowStatus>({
    status: 'unknown',
    conclusion: null,
    url: null,
    loading: true,
  });

  useEffect(() => {
    async function fetchStatus() {
      try {
        // Only fetch real data in production environment
        if (process.env.NODE_ENV === 'production') {
          // First, get the workflow ID for the test workflow
          const workflowsResponse = await fetch(
            'https://api.github.com/repos/DocSpring/logstruct/actions/workflows',
          );

          if (!workflowsResponse.ok) {
            setWorkflowStatus({
              status: 'unknown',
              conclusion: null,
              url: null,
              loading: false,
            });
            return;
          }

          const workflowsData = await workflowsResponse.json();
          const testWorkflow = workflowsData.workflows?.find(
            (workflow: { path: string; name: string }) =>
              workflow.path === '.github/workflows/test.yml' ||
              workflow.name.toLowerCase().includes('test'),
          );

          if (!testWorkflow) {
            setWorkflowStatus({
              status: 'unknown',
              conclusion: null,
              url: null,
              loading: false,
            });
            return;
          }

          // Now get the latest run for this specific workflow
          const runsResponse = await fetch(
            `https://api.github.com/repos/DocSpring/logstruct/actions/workflows/${testWorkflow.id}/runs?per_page=1&branch=main`,
          );

          if (!runsResponse.ok) {
            setWorkflowStatus({
              status: 'unknown',
              conclusion: null,
              url: null,
              loading: false,
            });
            return;
          }

          const runsData = await runsResponse.json();

          if (runsData.workflow_runs && runsData.workflow_runs.length > 0) {
            const latestRun = runsData.workflow_runs[0];
            setWorkflowStatus({
              status: latestRun.status,
              conclusion: latestRun.conclusion,
              url: latestRun.html_url,
              loading: false,
            });
          } else {
            setWorkflowStatus({
              status: 'unknown',
              conclusion: null,
              url: null,
              loading: false,
            });
          }
        } else {
          // In development, just return a successful status to avoid API rate limits
          setWorkflowStatus({
            status: 'completed',
            conclusion: 'success',
            url: 'https://github.com/DocSpring/logstruct/actions',
            loading: false,
          });
        }
      } catch (error) {
        console.error('Error fetching GitHub workflow status:', error);
        setWorkflowStatus({
          status: 'unknown',
          conclusion: null,
          url: null,
          loading: false,
        });
      }
    }

    fetchStatus();
  }, []);

  return (
    <a
      href={
        workflowStatus.url || 'https://github.com/DocSpring/logstruct/actions'
      }
      target="_blank"
      rel="noopener noreferrer"
      className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800 hover:border-gray-400 dark:hover:border-gray-500 transition-colors hover:no-underline"
    >
      <div className="flex items-center mb-4">
        <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 dark:bg-blue-900/30">
          <Github className="h-5 w-5 text-blue-500 dark:text-blue-400" />
        </div>
        <h3 className="text-xl font-semibold">Build Status</h3>
      </div>
      <p className="text-neutral-600 dark:text-neutral-300">
        CI/CD pipeline status:{' '}
        {workflowStatus.loading ? (
          <span className="text-blue-600 dark:text-blue-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              <Loader2 className="h-4 w-4 animate-spin" />
            </span>
            <span>Loading...</span>
          </span>
        ) : workflowStatus.conclusion === 'success' ? (
          <span className="text-green-600 dark:text-green-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ✓
            </span>
            <span>Passing</span>
          </span>
        ) : workflowStatus.conclusion === 'failure' ? (
          <span className="text-red-600 dark:text-red-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ✗
            </span>
            <span>Failing</span>
          </span>
        ) : workflowStatus.status === 'in_progress' ? (
          <span className="text-yellow-600 dark:text-yellow-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ⟳
            </span>
            <span>Running</span>
          </span>
        ) : workflowStatus.conclusion === 'cancelled' ? (
          <span className="text-orange-600 dark:text-orange-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ×
            </span>
            <span>Cancelled</span>
          </span>
        ) : workflowStatus.conclusion === 'skipped' ? (
          <span className="text-blue-500 dark:text-blue-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ⤭
            </span>
            <span>Skipped</span>
          </span>
        ) : workflowStatus.conclusion === 'timed_out' ? (
          <span className="text-red-600 dark:text-red-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ⏱
            </span>
            <span>Timed Out</span>
          </span>
        ) : workflowStatus.conclusion === 'action_required' ? (
          <span className="text-orange-600 dark:text-orange-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ⚠
            </span>
            <span>Action Required</span>
          </span>
        ) : workflowStatus.conclusion === 'neutral' ? (
          <span className="text-neutral-600 dark:text-neutral-300 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ◯
            </span>
            <span>Neutral</span>
          </span>
        ) : workflowStatus.conclusion === 'stale' ? (
          <span className="text-gray-600 dark:text-gray-400 font-semibold inline-flex items-center h-5">
            <span className="flex items-center justify-center h-4 w-4 mr-1">
              ⊖
            </span>
            <span>Stale</span>
          </span>
        ) : (
          <span className="text-neutral-600 dark:text-neutral-300 font-semibold inline-flex items-center h-5">
            <span>
              {workflowStatus.conclusion || workflowStatus.status || 'Unknown'}
            </span>
          </span>
        )}
      </p>
    </a>
  );
}
