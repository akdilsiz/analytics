/** @format */

import React, { useMemo, useRef, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownMenuWrapper,
  DropdownNavigationLink,
  ToggleDropdownButton
} from '../components/dropdown'
import { MagnifyingGlassIcon } from '@heroicons/react/20/solid'
import {
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup
} from '../util/filters'
import { PlausibleSite, useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { useOnClickOutside } from '../util/use-on-click-outside'
import { useQuery } from '@tanstack/react-query'
import { Filter } from '../query'
import { useQueryContext } from '../query-context'

const SEGMENT_LABEL_KEY_PREFIX = 'segment-'

export function isSegmentIdLabelKey(labelKey: string): boolean {
  return labelKey.startsWith(SEGMENT_LABEL_KEY_PREFIX)
}

export function formatSegmentIdAsLabelKey(id: number): string {
  return `${SEGMENT_LABEL_KEY_PREFIX}${id}`
}

export function getFilterListItems({
  propsAvailable
}: Pick<PlausibleSite, 'propsAvailable'>): {
  modalKey: string
  label: string
}[] {
  const allKeys = Object.keys(FILTER_MODAL_TO_FILTER_GROUP) as Array<
    keyof typeof FILTER_MODAL_TO_FILTER_GROUP
  >
  const keysToOmit: Array<keyof typeof FILTER_MODAL_TO_FILTER_GROUP> =
    propsAvailable ? ['segment'] : ['segment', 'props']
  return allKeys
    .filter((k) => !keysToOmit.includes(k))
    .map((modalKey) => ({ modalKey, label: formatFilterGroup(modalKey) }))
}

export const isSegmentFilter = (f: Filter): boolean => f[1] === 'segment'

export const SegmentsList = () => {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const { data } = useQuery({
    queryKey: ['segments'],
    placeholderData: (previousData) => previousData,
    queryFn: async () => {
      const response = await fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments`,
        {
          method: 'GET',
          headers: { 'content-type': 'application/json' }
        }
      ).then((res) => res.json() as Promise<{ name: string; id: number }[]>)
      return response
    }
  })

  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = segmentFilter ? segmentFilter[2] : []

  return (
    !!data?.length && (
      <DropdownLinkGroup>
        {data.map(({ name, id }) => (
          <DropdownNavigationLink
            key={id}
            active={appliedSegmentIds.includes(id)}
            search={(search) => {
              const otherFilters = query.filters.filter(
                (f) => !isSegmentFilter(f)
              )

              if (appliedSegmentIds.includes(id)) {
                const updatedSegmentIds = appliedSegmentIds.filter(
                  (appliedId) => appliedId !== id
                ) as number[]
                const updatedLabels = Object.fromEntries(
                  Object.entries(query.labels).filter(([k, _v]) =>
                    isSegmentIdLabelKey(k)
                      ? updatedSegmentIds
                          .map(formatSegmentIdAsLabelKey)
                          .includes(formatSegmentIdAsLabelKey(id))
                      : true
                  )
                )
                if (!updatedSegmentIds.length) {
                  return {
                    ...search,
                    filters: otherFilters,
                    labels: updatedLabels
                  }
                }
                return {
                  ...search,
                  filters: [
                    ['is', 'segment', updatedSegmentIds],
                    ...otherFilters
                  ],
                  labels: updatedLabels
                }
              }

              const updatedSegmentIds = [id, ...appliedSegmentIds] as number[]
              const updatedFilters = [
                ['is', 'segment', updatedSegmentIds],
                ...otherFilters
              ]
              const updatedLabels = Object.fromEntries(
                Object.entries(query.labels)
                  .concat([[formatSegmentIdAsLabelKey(id), name]])
                  .filter(([k, _v]) =>
                    isSegmentIdLabelKey(k)
                      ? updatedSegmentIds
                          .map(formatSegmentIdAsLabelKey)
                          .includes(formatSegmentIdAsLabelKey(id))
                      : true
                  )
              )

              return {
                ...search,
                filters: updatedFilters,
                labels: updatedLabels
              }
            }}
          >
            {name}
          </DropdownNavigationLink>
        ))}
      </DropdownLinkGroup>
    )
  )
}

export const FilterMenu = () => {
  const dropdownRef = useRef<HTMLDivElement>(null)
  const [opened, setOpened] = useState(false)
  const site = useSiteContext()
  const filterListItems = useMemo(() => getFilterListItems(site), [site])

  useOnClickOutside({
    ref: dropdownRef,
    active: opened,
    handler: () => setOpened(false)
  })
  return (
    <ToggleDropdownButton
      ref={dropdownRef}
      variant="ghost"
      className="ml-auto md:relative"
      dropdownContainerProps={{
        ['aria-controls']: 'filter-menu',
        ['aria-expanded']: opened
      }}
      onClick={() => setOpened((opened) => !opened)}
      currentOption={
        <span className="flex items-center">
          <MagnifyingGlassIcon className="block h-4 w-4" />
          <span className="block ml-1">Filter</span>
        </span>
      }
    >
      {opened && (
        <DropdownMenuWrapper id="filter-menu" className="md:left-auto md:w-56">
          <DropdownLinkGroup>
            {filterListItems.map(({ modalKey, label }) => (
              <DropdownNavigationLink
                active={false}
                key={modalKey}
                path={filterRoute.path}
                params={{ field: modalKey }}
                search={(search) => search}
              >
                {label}
              </DropdownNavigationLink>
            ))}
          </DropdownLinkGroup>
        </DropdownMenuWrapper>
      )}
    </ToggleDropdownButton>
  )
}
