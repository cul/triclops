import React, { useState, useEffect } from 'react';
import '../stylesheets/triclops_v1.scss'; // app css entry point
import { RouterProvider, createBrowserRouter } from 'react-router-dom';
import HomePage from '../pages/Home';
import ResourcesPage from '../pages/Resources';

const router = createBrowserRouter([
  {
    path: '/',
    children: [
      { index: true, element: <HomePage /> },
      { path: '/admin/resources', element: <ResourcesPage /> }
    ]
  }
])

const App = () => {
  return <RouterProvider router={router} />;
};

export default App;
