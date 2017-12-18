'use strict';

/**
 * @ngdoc function
 * @name mobileControlPanelApp.controller:MobileAppController
 * @description
 * # MobileAppController
 * Controller of the mobileControlPanelApp
 */
angular.module('mobileControlPanelApp').controller('MobileAppController', [
  '$scope',
  '$location',
  '$routeParams',
  '$filter',
  'ProjectsService',
  'McpService',
  'DataService',
  'BuildsService',
  function(
    $scope,
    $location,
    $routeParams,
    $filter,
    ProjectsService,
    McpService,
    DataService,
    BuildsService
  ) {
    $scope.alerts = {};
    $scope.renderOptions = $scope.renderOptions || {};
    $scope.renderOptions.hideFilterWidget = true;
    $scope.breadcrumbs = [
      {
        title: 'Overview',
        link: 'project/' + $routeParams.project + '/overview'
      },
      {
        title: $routeParams.mobileapp
      }
    ];
  }
]);
