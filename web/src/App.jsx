import { lazy, Suspense } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import '@fontsource-variable/inter';
import AuthProvider from './auth/AuthProvider';
import LoginPage from './auth/LoginPage';
import RequireRole from './auth/RequireRole';
import AppShell from './layout/AppShell';

// Admin code is split out so the customer form stays small and fast on mobile.
const FeedbackListPage = lazy(() => import('./shared/FeedbackListPage'));
const DashboardPage = lazy(() => import('./admin/DashboardPage'));
const QuestionsPage = lazy(() => import('./admin/QuestionsPage'));
const CategoriesPage = lazy(() => import('./admin/CategoriesPage'));
const CompaniesPage = lazy(() => import('./admin/CompaniesPage'));
const CompanyDetailPage = lazy(() => import('./admin/CompanyDetailPage'));
const RequestsPage = lazy(() => import('./admin/RequestsPage'));
const RequestQuestionPage = lazy(() => import('./business/RequestQuestionPage'));

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route
          path="/*"
          element={
            <AuthProvider>
              <Suspense fallback={<div className="center" role="status">Loading…</div>}>
                <Routes>
                  <Route path="/login" element={<LoginPage />} />
                  <Route element={<RequireRole role="super_admin" />}>
                    <Route element={<AppShell />}>
                      <Route path="/admin" element={<DashboardPage />} />
                      <Route path="/admin/feedback" element={<FeedbackListPage />} />
                      <Route path="/admin/questions" element={<QuestionsPage />} />
                      <Route path="/admin/categories" element={<CategoriesPage />} />
                      <Route path="/admin/companies" element={<CompaniesPage />} />
                      <Route path="/admin/companies/:id" element={<CompanyDetailPage />} />
                      <Route path="/admin/requests" element={<RequestsPage />} />
                    </Route>
                  </Route>
                  <Route element={<RequireRole role="business_admin" />}>
                    <Route element={<AppShell />}>
                      <Route path="/business" element={<FeedbackListPage />} />
                      <Route path="/business/request" element={<RequestQuestionPage />} />
                    </Route>
                  </Route>
                  <Route path="*" element={<Navigate to="/login" replace />} />
                </Routes>
              </Suspense>
            </AuthProvider>
          }
        />
      </Routes>
    </BrowserRouter>
  );
}
